// SPDX-FileCopyrightText: 2026 CikeSeven
// SPDX-License-Identifier: MIT
// See THIRD_PARTY_NOTICES.md.
//
// Paints the composer's draft over a transparent EditableText. The real field
// keeps IME, selection, scrolling and key handling; this layer only draws
// glyphs that just arrived or are leaving. Nothing here edits the controller.

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../performance/performance_state.dart';
import '../theme/motion.dart';

const int _trailLength = 8;

enum _GlyphPhase { entering, steady, exiting }

class _Glyph {
  _Glyph(this.id, this.text, this.phase, this.started);

  final int id;
  final String text;
  _GlyphPhase phase;
  Duration started;
  TextPainter? painter;
  Rect? rect;
  double width = 0;
  bool remove = false;
  int batchIndex = 0;
}

/// The animated text layer above the composer's [TextField].
///
/// Text is grouped by grapheme cluster (emoji and combining marks stay whole)
/// and reuses a glyph id whenever the same cluster survives an edit, so typing
/// in the middle does not restart every letter. IME composition is drawn
/// without animation: the IME may rewrite the text several times per word.
class AnimatedComposerText extends StatefulWidget {
  const AnimatedComposerText({
    super.key,
    required this.controller,
    required this.style,
    required this.textPad,
    required this.maxLines,
    required this.textDirection,
    this.locale,
    this.scrollOffset = 0,
    this.letterDuration = const Duration(milliseconds: 320),
    this.deleteDuration = const Duration(milliseconds: 200),
    this.slideDistance = 10,
    required this.cursorColor,
    this.cursorWidth = 2,
    this.deleteMode = TextAnimationDelete.fallAway,
    this.cursorMode = TextAnimationCursor.glide,
    this.animateLetters = true,
    this.slideUp = true,
    this.unblur = false,
    this.pop = false,
    this.tilt = false,
    this.trailEnabled = true,
    this.cursorSpeed = 18,
    this.popStrength = 100,
    this.tiltStrength = 100,
  });

  final TextEditingController controller;
  final TextStyle style;
  final double textPad;
  final int maxLines;
  final TextDirection textDirection;
  final Locale? locale;
  final double scrollOffset;

  /// How long one letter takes to settle. A batch of new letters is staggered
  /// by [AppMotion.stagger], capped at [AppMotion.staggerLimit] letters.
  final Duration letterDuration;
  final Duration deleteDuration;
  final double slideDistance;
  final Color cursorColor;
  final double cursorWidth;
  final TextAnimationDelete deleteMode;
  final TextAnimationCursor cursorMode;
  final bool animateLetters;
  final bool slideUp;
  final bool unblur;
  final bool pop;
  final bool tilt;
  final bool trailEnabled;
  final int cursorSpeed;
  final int popStrength;
  final int tiltStrength;

  @override
  AnimatedComposerTextState createState() => AnimatedComposerTextState();
}

@visibleForTesting
class AnimatedComposerTextState extends State<AnimatedComposerText> with SingleTickerProviderStateMixin {
  final List<_Glyph> _glyphs = <_Glyph>[];
  late final Ticker _ticker = Ticker(_tick, debugLabel: 'AnimatedComposerText');
  Duration _now = Duration.zero;
  int _nextId = 0;
  String _text = '';
  double _width = 0;
  TextPainter? _whole;
  int _selectionOffset = 0;
  Rect? _caretRect;
  Offset _cursorTarget = Offset.zero;
  Offset _cursor = Offset.zero;
  Offset _cursorVelocity = Offset.zero;
  bool _cursorReady = false;
  final List<Offset> _trail = <Offset>[];

  /// Number of glyphs still moving; used by tests to check that a batch ends.
  @visibleForTesting
  int get activeGlyphs => _glyphs.where((g) => g.phase != _GlyphPhase.steady).length;

  bool get _active => _glyphs.any((g) => g.phase != _GlyphPhase.steady);

  bool get _cursorMoving =>
      _caretRect != null &&
      ((_cursorTarget - _cursor).distanceSquared > 0.25 || _cursorVelocity.distanceSquared > 0.25);

  @override
  void initState() {
    super.initState();
    _text = widget.controller.text;
    _diff();
    // A draft that is already there when the field mounts is not "typed":
    // show it at once. Only later controller changes animate.
    for (final glyph in _glyphs) {
      glyph.phase = _GlyphPhase.steady;
    }
    _selectionOffset = widget.controller.selection.baseOffset;
    _updateCaretTarget();
    if (!_cursorReady) {
      _cursor = _cursorTarget;
      _cursorReady = true;
    }
    widget.controller.addListener(_onController);
  }

  @override
  void didUpdateWidget(AnimatedComposerText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _text = widget.controller.text;
      _diff();
      _relayout();
    } else if (oldWidget.style != widget.style || oldWidget.maxLines != widget.maxLines) {
      _relayout();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    _ticker.dispose();
    _whole?.dispose();
    for (final glyph in _glyphs) {
      glyph.painter?.dispose();
    }
    super.dispose();
  }

  void _onController() {
    if (!mounted) return;
    final value = widget.controller.value;
    final textChanged = value.text != _text;
    final selectionChanged = value.selection.baseOffset != _selectionOffset;
    if (!textChanged && !selectionChanged) return;
    setState(() {
      if (textChanged) {
        _text = value.text;
        _diff();
        _relayout();
      } else {
        _updateCaretTarget();
      }
      _selectionOffset = value.selection.baseOffset;
    });
    if (_active || _cursorMoving) _ticker.start();
  }

  void _diff() {
    // While the IME is composing, every intermediate revision is a rewrite of
    // the same word. Show it immediately and let the IME's underline do its job.
    final composing = widget.controller.value.composing.isValid;
    final incoming = _text.characters.toList();
    final oldById = <int, _Glyph>{for (final glyph in _glyphs) glyph.id: glyph};
    final alreadyLeaving = _glyphs.where((g) => g.phase == _GlyphPhase.exiting).toList();
    final available = <String, List<_Glyph>>{};
    for (final glyph in _glyphs) {
      if (glyph.phase == _GlyphPhase.exiting) continue;
      (available[glyph.text] ??= <_Glyph>[]).add(glyph);
    }

    final next = <_Glyph>[];
    var created = 0;
    for (final cluster in incoming) {
      final pool = available[cluster];
      if (pool != null && pool.isNotEmpty) {
        final reused = pool.removeAt(0);
        if (composing) reused.phase = _GlyphPhase.steady;
        next.add(reused);
      } else {
        final immediate = composing || !widget.animateLetters;
        final glyph = _Glyph(_nextId++, cluster, immediate ? _GlyphPhase.steady : _GlyphPhase.entering, _now);
        glyph.batchIndex = created.clamp(0, AppMotion.staggerLimit);
        created++;
        next.add(glyph);
      }
    }

    final kept = next.map((g) => g.id).toSet();
    final animateDelete = widget.deleteMode != TextAnimationDelete.none;
    for (final glyph in oldById.values) {
      if (!animateDelete ||
          glyph.phase == _GlyphPhase.exiting ||
          kept.contains(glyph.id) ||
          composing) {
        continue;
      }
      glyph
        ..phase = _GlyphPhase.exiting
        ..started = _now;
      next.add(glyph);
    }
    // A deleted glyph keeps its old box while it falls away: the rest of the
    // line has already moved on, which is exactly what a falling letter wants.
    if (animateDelete) {
      for (final glyph in alreadyLeaving) {
        if (!glyph.remove && _now - glyph.started < widget.deleteDuration) next.add(glyph);
      }
    }
    _glyphs
      ..clear()
      ..addAll(next);
  }

  void _relayout() {
    if (_width <= 0) return;
    final scaler = MediaQuery.textScalerOf(context);
    _whole?.dispose();
    _whole = TextPainter(
      text: TextSpan(text: _text, style: widget.style),
      textDirection: widget.textDirection,
      maxLines: widget.maxLines,
      textScaler: scaler,
      locale: widget.locale,
    )..layout(maxWidth: _width);
    final whole = _whole!;

    var offset = 0;
    for (final glyph in _glyphs) {
      if (glyph.phase == _GlyphPhase.exiting) continue;
      final painter = TextPainter(
        text: TextSpan(text: glyph.text, style: widget.style),
        textDirection: widget.textDirection,
        textScaler: scaler,
        locale: widget.locale,
      )..layout(maxWidth: _width);
      glyph.painter?.dispose();
      glyph.painter = painter;
      glyph.width = painter.width;
      final boxes = whole.getBoxesForSelection(
        TextSelection(baseOffset: offset, extentOffset: offset + glyph.text.length),
      );
      glyph.rect = boxes.isEmpty ? null : boxes.first.toRect();
      offset += glyph.text.length;
    }
    _updateCaretTarget();
  }

  Rect? _caretRectAt(int offset) {
    final painter = _whole;
    if (painter == null) return null;
    final safe = math.max(0, math.min(offset, _text.length));
    final boxes = painter.getBoxesForSelection(TextSelection.collapsed(offset: safe));
    if (boxes.isNotEmpty) return boxes.first.toRect();
    if (safe > 0) {
      final before = painter.getBoxesForSelection(TextSelection(baseOffset: safe - 1, extentOffset: safe));
      if (before.isNotEmpty) {
        final box = before.last.toRect();
        final x = widget.textDirection == TextDirection.rtl ? box.left : box.right;
        return Rect.fromLTWH(x, box.top, 0, box.height);
      }
    }
    final fontSize = widget.style.fontSize ?? 15;
    return Rect.fromLTWH(0, 0, 0, fontSize * 1.45);
  }

  void _updateCaretTarget() {
    _caretRect = _caretRectAt(widget.controller.selection.baseOffset);
    final rect = _caretRect;
    if (rect == null) return;
    final x = widget.textDirection == TextDirection.rtl ? rect.right : rect.left;
    _cursorTarget = Offset(x, rect.top);
    if (!_cursorReady) {
      _cursor = _cursorTarget;
      _cursorReady = true;
    }
  }

  void _tick(Duration elapsed) {
    _now += elapsed;
    for (final glyph in _glyphs) {
      if (glyph.phase == _GlyphPhase.entering &&
          _now - glyph.started >= widget.letterDuration + AppMotion.stagger * glyph.batchIndex) {
        glyph.phase = _GlyphPhase.steady;
      } else if (glyph.phase == _GlyphPhase.exiting && _now - glyph.started >= widget.deleteDuration) {
        glyph.remove = true;
      }
    }
    _glyphs.removeWhere((glyph) => glyph.remove);

    // A spring, not a tween: a fast retype keeps the caret's speed and glides
    // to the new glyph instead of snapping between two offsets.
    final dt = (elapsed.inMicroseconds / 1000000).clamp(0.0, 0.032);
    if (_caretRect != null && dt > 0) {
      if (widget.cursorMode == TextAnimationCursor.glide) {
        final stiffness = 80.0 + widget.cursorSpeed * 8.0;
        final damping = math.sqrt(stiffness) * 2.4;
        final dx = _cursorTarget.dx - _cursor.dx;
        final dy = _cursorTarget.dy - _cursor.dy;
        final vx = _cursorVelocity.dx + (stiffness * dx - damping * _cursorVelocity.dx) * dt;
        final vy = _cursorVelocity.dy + (stiffness * dy - damping * _cursorVelocity.dy) * dt;
        _cursor = Offset(_cursor.dx + vx * dt, _cursor.dy + vy * dt);
        _cursorVelocity = Offset(vx, vy);
      } else {
        _cursor = _cursorTarget;
        _cursorVelocity = Offset.zero;
      }
      if (_cursorMoving) {
        if (widget.trailEnabled && (_trail.isEmpty || (_trail.first - _cursor).distance > 1.5)) {
          _trail.insert(0, _cursor);
          if (_trail.length > _trailLength) _trail.removeLast();
        }
      } else {
        _cursor = _cursorTarget;
        _cursorVelocity = Offset.zero;
        _trail.clear();
      }
    }
    if (!_active && !_cursorMoving) _ticker.stop();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width.isFinite && width > 0 && width != _width) {
          _width = width;
          _relayout();
        }
        return CustomPaint(
          painter: _GlyphPainter(
            glyphs: List<_Glyph>.of(_glyphs),
            baseStyle: widget.style,
            now: _now,
            textPad: widget.textPad,
            scrollOffset: widget.scrollOffset,
            letterDuration: widget.letterDuration,
            deleteDuration: widget.deleteDuration,
            slideDistance: widget.slideDistance,
            direction: widget.textDirection,
            scaler: MediaQuery.textScalerOf(context),
            locale: widget.locale,
            cursorColor: widget.cursorColor,
            cursorWidth: widget.cursorWidth,
            cursorOffset: _cursor,
            caretRect: _caretRect,
            trail: List<Offset>.of(_trail),
            deleteMode: widget.deleteMode,
            slideUp: widget.slideUp,
            unblur: widget.unblur,
            pop: widget.pop,
            tilt: widget.tilt,
            trailEnabled: widget.trailEnabled,
            popStrength: widget.popStrength,
            tiltStrength: widget.tiltStrength,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter({
    required this.glyphs,
    required this.baseStyle,
    required this.now,
    required this.textPad,
    required this.scrollOffset,
    required this.letterDuration,
    required this.deleteDuration,
    required this.slideDistance,
    required this.direction,
    required this.scaler,
    required this.locale,
    required this.cursorColor,
    required this.cursorWidth,
    required this.cursorOffset,
    required this.caretRect,
    required this.trail,
    required this.deleteMode,
    required this.slideUp,
    required this.unblur,
    required this.pop,
    required this.tilt,
    required this.trailEnabled,
    required this.popStrength,
    required this.tiltStrength,
  });

  final List<_Glyph> glyphs;
  final TextStyle baseStyle;
  final Duration now;
  final double textPad;
  final double scrollOffset;
  final Duration letterDuration;
  final Duration deleteDuration;
  final double slideDistance;
  final TextDirection direction;
  final TextScaler scaler;
  final Locale? locale;
  final Color cursorColor;
  final double cursorWidth;
  final Offset cursorOffset;
  final Rect? caretRect;
  final List<Offset> trail;
  final TextAnimationDelete deleteMode;
  final bool slideUp;
  final bool unblur;
  final bool pop;
  final bool tilt;
  final bool trailEnabled;
  final int popStrength;
  final int tiltStrength;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final origin = Offset(0, textPad - scrollOffset);

    for (final glyph in glyphs) {
      final rect = glyph.rect;
      final cached = glyph.painter;
      if (rect == null || cached == null) continue;
      final elapsedMs = (now - glyph.started).inMicroseconds / 1000;
      final p = deleteDuration.inMicroseconds == 0
          ? 1.0
          : ((now - glyph.started).inMicroseconds / deleteDuration.inMicroseconds).clamp(0.0, 1.0);
      var opacity = 1.0;
      var dx = 0.0;
      var dy = 0.0;
      var scale = 1.0;
      var rotate = 0.0;
      var blurSigma = 0.0;

      if (glyph.phase == _GlyphPhase.entering) {
        // Only the first [AppMotion.staggerLimit] letters of a batch wait;
        // pasting a page must not take a second to finish.
        final start = glyph.batchIndex * AppMotion.stagger.inMilliseconds;
        final local = ((elapsedMs - start) / letterDuration.inMilliseconds).clamp(0.0, 1.0);
        final eased = Curves.easeOut.transform(local);
        opacity = eased;
        if (slideUp) dy = (1 - eased) * slideDistance;
        if (pop) {
          scale = 1 + (AppMotion.popCurve.transform(local) - 1) * (popStrength / 100) * 0.12;
        }
        if (tilt) {
          rotate = 0.7 *
              (tiltStrength / 100) *
              math.pow(1 - eased, 1.2).toDouble() *
              math.cos(local * 3.5 * math.pi) *
              (glyph.id.isEven ? 1 : -1);
        }
        if (unblur) blurSigma = (1 - eased) * 8;
      } else if (glyph.phase == _GlyphPhase.exiting) {
        opacity = 1 - p;
        switch (deleteMode) {
          case TextAnimationDelete.fallAway:
            dy = p * p * 18;
            dx = (glyph.id % 3 - 1) * p * 6;
            scale = 1 - 0.2 * p;
          case TextAnimationDelete.dust:
            dy = -p * 10;
            dx = ((glyph.id * 7) % 5 - 2) * p * 4;
            scale = 1 - 0.6 * p;
            rotate = p * (glyph.id.isEven ? 0.5 : -0.5);
          case TextAnimationDelete.none:
            opacity = 0;
        }
      }
      if (opacity <= 0) continue;

      var painter = cached;
      if (opacity < 1) {
        final color = baseStyle.color ?? const Color(0xFF000000);
        painter = TextPainter(
          text: TextSpan(
            text: glyph.text,
            style: baseStyle.copyWith(color: color.withValues(alpha: opacity)),
          ),
          textDirection: direction,
          textScaler: scaler,
          locale: locale,
        )..layout(maxWidth: glyph.width + 1);
      }

      final pos = rect.topLeft + origin;
      final cx = pos.dx + rect.width / 2;
      final cy = pos.dy + rect.height / 2;
      canvas.save();
      canvas.translate(cx + dx, cy + dy);
      if (rotate != 0) canvas.rotate(rotate);
      if (scale != 1) canvas.scale(scale, scale);
      canvas.translate(-cx, -cy);
      if (blurSigma > 0) {
        canvas.saveLayer(
          rect.inflate(12).shift(pos - rect.topLeft),
          Paint()..imageFilter = ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        );
      }
      painter.paint(canvas, pos);
      if (blurSigma > 0) canvas.restore();
      canvas.restore();
      if (!identical(painter, cached)) painter.dispose();
    }

    final caret = caretRect;
    if (caret != null) {
      for (var i = trailEnabled ? trail.length - 1 : 0; i >= 1; i--) {
        final fade = 1 - i / trail.length;
        canvas.drawLine(
          trail[i] + origin,
          trail[i - 1] + origin,
          Paint()
            ..color = cursorColor.withValues(alpha: 0.25 * fade)
            ..strokeWidth = cursorWidth * fade
            ..strokeCap = StrokeCap.round,
        );
      }
      final pulse = 0.55 + 0.45 * math.sin(now.inMilliseconds / 190);
      canvas.drawLine(
        Offset(cursorOffset.dx, caret.top + origin.dy),
        Offset(cursorOffset.dx, caret.bottom + origin.dy),
        Paint()
          ..color = cursorColor.withValues(alpha: pulse)
          ..strokeWidth = cursorWidth
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.now != now ||
      oldDelegate.scrollOffset != scrollOffset ||
      oldDelegate.textPad != textPad ||
      oldDelegate.cursorOffset != cursorOffset ||
      oldDelegate.caretRect != caretRect ||
      oldDelegate.trail.length != trail.length ||
      oldDelegate.deleteMode != deleteMode ||
      oldDelegate.slideUp != slideUp ||
      oldDelegate.unblur != unblur ||
      oldDelegate.pop != pop ||
      oldDelegate.tilt != tilt ||
      oldDelegate.trailEnabled != trailEnabled ||
      !identical(oldDelegate.glyphs, glyphs);
}
