// SPDX-FileCopyrightText: 2026 CikeSeven
// SPDX-License-Identifier: MIT
// See THIRD_PARTY_NOTICES.md.
//
// Port of ValencedPlugins' TypingFx (plugins/textanimation). A transparent
// TextField keeps IME, selection, scrolling and key handling; this layer paints
// what the plugin draws over the native EditText: staggered letters, particle
// delete effects and a gliding caret. The controller is never edited here.

import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../performance/performance_state.dart';

/// Plugin caps: at most this many clusters animate per edit, at most this many
/// particles survive at once, and clearing more than this many letters with one
/// backspace skips the effect.
const int _maxAnimated = 150;
const int _maxBits = 220;
const int _maxClearEffect = 3;
const int _dustPerGlyph = 7;

enum _GlyphPhase { entering, steady }

class _Glyph {
  _Glyph(this.id, this.text, this.phase, this.started);

  final int id;
  final String text;
  _GlyphPhase phase;
  Duration started;
  TextPainter? painter;
  Rect? rect;
  double width = 0;
}

class _Bit {
  _Bit({
    required this.text,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.angle,
    required this.spin,
    required this.size,
    required this.born,
    required this.life,
    required this.color,
    required this.gravity,
  });

  final String? text;
  double x;
  double y;
  double vx;
  double vy;
  double angle; // radians
  final double spin; // radians per second
  final double size;
  final Duration born;
  final Duration life;
  final Color color;
  final double gravity; // logical pixels per second squared
}

/// The animated text layer above the composer's [TextField].
///
/// Glyphs are grapheme clusters (emoji and combining marks stay whole). The
/// edit diff is the plugin's common-prefix / common-suffix scan, so only the
/// letters that actually arrived animate — a paste ripples in, an edit in the
/// middle leaves the rest alone. IME composition is drawn without animation:
/// the IME rewrites the same word several times per keystroke.
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
    this.slideDistance = 10,
    required this.cursorColor,
    this.cursorWidth = 2,
    this.deleteMode = TextAnimationDelete.fallAway,
    this.cursorMode = TextAnimationCursor.glide,
    this.animateLetters = true,
    this.slideUp = true,
    this.unblur = true,
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

  /// Duration of one letter, including its ease-out settle (plugin: 320 ms).
  final Duration letterDuration;
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
  final List<_Bit> _bits = <_Bit>[];
  final math.Random _random = math.Random();
  late final Ticker _ticker = Ticker(_tick, debugLabel: 'AnimatedComposerText');
  Duration _now = Duration.zero;
  int _nextId = 0;
  String _text = '';
  double _width = 0;
  TextPainter? _whole;
  int _selectionOffset = 0;

  Rect? _caretRect;
  double _targetX = 0;
  double _targetTop = 0;
  double _curX = 0;
  double _curTop = 0;
  double _curBottom = 0;
  double _trailX = 0;
  bool _cursorReady = false;
  Duration _lastMove = Duration.zero;

  /// Number of letters still settling. Bits are tracked separately because a
  /// deleted letter leaves the glyph list and becomes a particle.
  @visibleForTesting
  int get activeGlyphs => _glyphs.where((g) => g.phase == _GlyphPhase.entering).length;

  @visibleForTesting
  int get activeBits => _bits.length;

  bool get _active => activeGlyphs > 0 || _bits.isNotEmpty;

  bool get _cursorMoving {
    if (_caretRect == null) return false;
    return (_targetX - _curX).abs() > 0.3 ||
        (_targetTop - _curTop).abs() > 0.3 ||
        (_curX - _trailX).abs() > 0.3;
  }

  double get _cursorAlpha {
    if (!_cursorMoving) return 1;
    final since = (_now - _lastMove).inMilliseconds;
    if (since < 500) return 1;
    // Plugin: fade in place of blinking once the caret has been still a while.
    return 0.5 + 0.5 * math.cos(2 * math.pi * (since - 500) / 1100);
  }

  double get _fontSize => widget.style.fontSize ?? 15;

  @override
  void initState() {
    super.initState();
    _text = widget.controller.text;
    // A draft already present when the field mounts was not "typed": show it
    // at once and only animate later controller changes.
    for (final cluster in _text.characters) {
      _glyphs.add(_Glyph(_nextId++, cluster, _GlyphPhase.steady, Duration.zero));
    }
    _selectionOffset = widget.controller.selection.baseOffset;
    _updateCaretTarget();
    widget.controller.addListener(_onController);
  }

  @override
  void didUpdateWidget(AnimatedComposerText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onController);
      widget.controller.addListener(_onController);
      _text = widget.controller.text;
      final initial = <_Glyph>[];
      for (final cluster in _text.characters) {
        initial.add(_Glyph(_nextId++, cluster, _GlyphPhase.steady, _now));
      }
      _glyphs
        ..clear()
        ..addAll(initial);
      _bits.clear();
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
        _diff(value.text);
        _relayout();
      } else {
        _updateCaretTarget();
      }
      _selectionOffset = value.selection.baseOffset;
    });
    if (_active || _cursorMoving) _ticker.start();
  }

  /// Plugin's onEdit: common prefix + common suffix, snapped to grapheme edges
  /// (Dart's [StringCharacters] already yields whole clusters).
  void _diff(String next) {
    final composing = widget.controller.value.composing.isValid;
    final incoming = next.characters.toList();
    final old = _text.characters.toList();
    if (_glyphs.length != old.length) {
      // A glyph list out of sync with the text cannot be indexed safely.
      final restored = <_Glyph>[];
      for (final cluster in old) {
        restored.add(_Glyph(_nextId++, cluster, _GlyphPhase.steady, _now));
      }
      _glyphs
        ..clear()
        ..addAll(restored);
    }

    var start = 0;
    final shared = math.min(old.length, incoming.length);
    while (start < shared && old[start] == incoming[start]) {
      start++;
    }
    var suffix = 0;
    while (suffix < old.length - start &&
        suffix < incoming.length - start &&
        old[old.length - 1 - suffix] == incoming[incoming.length - 1 - suffix]) {
      suffix++;
    }
    final insEnd = incoming.length - suffix;
    final delEnd = old.length - suffix;

    final nextGlyphs = <_Glyph>[..._glyphs.sublist(0, math.min(start, _glyphs.length))];
    final removed = <_Glyph>[];

    // Deleted letters do not fade in place: the plugin turns them into bits.
    // Clearing a whole long draft in one backspace is deliberately not animated.
    final spawnBits = widget.deleteMode != TextAnimationDelete.none &&
        !composing &&
        !(incoming.isEmpty && delEnd - start > _maxClearEffect);
    for (var i = start; i < math.min(delEnd, _glyphs.length); i++) {
      if (spawnBits) _spawnBits(_glyphs[i]);
      removed.add(_glyphs[i]);
    }
    for (final glyph in removed) {
      glyph.painter?.dispose();
    }

    // Letters after the deleted run keep their identity; their boxes are
    // recomputed in _relayout so they shift into the new positions.
    for (var i = delEnd; i < _glyphs.length; i++) {
      nextGlyphs.add(_glyphs[i]);
    }

    final inserted = <_Glyph>[];
    for (var i = start; i < insEnd; i++) {
      final cluster = incoming[i];
      final animate = !composing &&
          widget.animateLetters &&
          cluster.trim().isNotEmpty &&
          inserted.length < _maxAnimated;
      inserted.add(
        _Glyph(
          _nextId++,
          cluster,
          animate ? _GlyphPhase.entering : _GlyphPhase.steady,
          _now,
        ),
      );
    }
    if (inserted.length > 1) {
      final gap = math.min(32, 520 / inserted.length).round();
      for (var i = 0; i < inserted.length; i++) {
        if (inserted[i].phase == _GlyphPhase.entering) {
          inserted[i].started = _now + Duration(milliseconds: gap * i);
        }
      }
    }
    nextGlyphs.insertAll(math.min(start, nextGlyphs.length), inserted);

    _text = next;
    _glyphs
      ..clear()
      ..addAll(nextGlyphs);
  }

  void _spawnBits(_Glyph glyph) {
    final rect = glyph.rect;
    if (rect == null) return;
    final baseline = rect.top + _fontSize * 0.82;
    final color = widget.style.color ?? const Color(0xFF000000);
    if (widget.deleteMode == TextAnimationDelete.fallAway) {
      _bits.add(_Bit(
        text: glyph.text,
        x: rect.left,
        y: baseline,
        vx: _random.nextDouble() * 70 - 35,
        vy: -(40 + _random.nextDouble() * 70),
        angle: 0,
        spin: (_random.nextDouble() * 360 - 180) * math.pi / 180,
        size: 0,
        born: _now,
        life: const Duration(milliseconds: 620),
        color: color,
        gravity: 900,
      ));
    } else if (widget.deleteMode == TextAnimationDelete.dust) {
      final cx = rect.left + rect.width / 2;
      final cy = baseline - _fontSize * 0.35;
      for (var i = 0; i < _dustPerGlyph; i++) {
        final angle = _random.nextDouble() * 2 * math.pi;
        final speed = 35 + _random.nextDouble() * 110;
        _bits.add(_Bit(
          text: null,
          x: cx + (_random.nextDouble() - 0.5) * rect.width,
          y: cy + (_random.nextDouble() - 0.5) * _fontSize * 0.5,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed - 40,
          angle: 0,
          spin: 0,
          size: 1.2 + _random.nextDouble() * 1.8,
          born: _now,
          life: Duration(milliseconds: 380 + _random.nextInt(220)),
          color: color,
          gravity: -60,
        ));
      }
    }
    while (_bits.length > _maxBits) {
      _bits.removeAt(0);
    }
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
      final blank = glyph.text.trim().isEmpty;
      final painter = blank
          ? null
          : (TextPainter(
              text: TextSpan(text: glyph.text, style: widget.style),
              textDirection: widget.textDirection,
              textScaler: scaler,
              locale: widget.locale,
            )..layout(maxWidth: _width));
      glyph.painter?.dispose();
      glyph.painter = painter;
      glyph.width = painter?.width ?? 0;
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
    return Rect.fromLTWH(0, 0, 0, _fontSize * 1.45);
  }

  void _seedCursor() {
    _curX = _targetX;
    _curTop = _targetTop;
    _curBottom = math.max(_targetTop + _fontSize * 1.2, _caretRect?.bottom ?? 0);
    _trailX = _targetX;
    _lastMove = _now;
    _cursorReady = true;
  }

  void _updateCaretTarget() {
    _caretRect = _caretRectAt(widget.controller.selection.baseOffset);
    final rect = _caretRect;
    if (rect == null) return;
    final x = widget.textDirection == TextDirection.rtl ? rect.right : rect.left;
    if (x != _targetX || rect.top != _targetTop) {
      _targetX = x;
      _targetTop = rect.top;
      _lastMove = _now;
    }
    if (!_cursorReady) _seedCursor();
  }

  void _tick(Duration elapsed) {
    _now += elapsed;
    final dt = (elapsed.inMicroseconds / 1000000).clamp(0.0, 0.032).toDouble();

    for (final glyph in _glyphs) {
      if (glyph.phase == _GlyphPhase.entering && _now >= glyph.started + widget.letterDuration) {
        glyph.phase = _GlyphPhase.steady;
      }
    }

    for (final bit in _bits) {
      bit.vy += bit.gravity * dt;
      bit.x += bit.vx * dt;
      bit.y += bit.vy * dt;
      bit.angle += bit.spin * dt;
    }
    _bits.removeWhere((bit) => _now - bit.born >= bit.life);

    if (_caretRect != null && widget.cursorMode == TextAnimationCursor.glide) {
      final rate = widget.cursorSpeed.toDouble();
      final k = 1 - math.exp(-rate * dt);
      _curX += (_targetX - _curX) * k;
      _curTop += (_targetTop - _curTop) * k;
      final bottom = math.max(_targetTop + _fontSize * 1.2, _caretRect!.bottom);
      _curBottom += (bottom - _curBottom) * k;
      _trailX = widget.trailEnabled
          ? _trailX + (_curX - _trailX) * (1 - math.exp(-rate * 0.4 * dt))
          : _curX;
    } else if (_caretRect != null) {
      _curX = _targetX;
      _curTop = _targetTop;
      _curBottom = math.max(_targetTop + _fontSize * 1.2, _caretRect!.bottom);
      _trailX = _curX;
    }

    if (!_active && !_cursorMoving) {
      _curX = _targetX;
      _curTop = _targetTop;
      _trailX = _curX;
      _ticker.stop();
    }
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
            bits: List<_Bit>.of(_bits),
            baseStyle: widget.style,
            now: _now,
            textPad: widget.textPad,
            scrollOffset: widget.scrollOffset,
            letterDuration: widget.letterDuration,
            slideDistance: widget.slideDistance,
            direction: widget.textDirection,
            scaler: MediaQuery.textScalerOf(context),
            locale: widget.locale,
            cursorColor: widget.cursorColor,
            cursorWidth: widget.cursorWidth,
            caretTop: _curTop,
            caretBottom: _curBottom,
            cursorX: _curX,
            trailX: _trailX,
            cursorAlpha: _cursorAlpha,
            deleteMode: widget.deleteMode,
            slideUp: widget.slideUp,
            unblur: widget.unblur,
            pop: widget.pop,
            tilt: widget.tilt,
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
    required this.bits,
    required this.baseStyle,
    required this.now,
    required this.textPad,
    required this.scrollOffset,
    required this.letterDuration,
    required this.slideDistance,
    required this.direction,
    required this.scaler,
    required this.locale,
    required this.cursorColor,
    required this.cursorWidth,
    required this.caretTop,
    required this.caretBottom,
    required this.cursorX,
    required this.trailX,
    required this.cursorAlpha,
    required this.deleteMode,
    required this.slideUp,
    required this.unblur,
    required this.pop,
    required this.tilt,
    required this.popStrength,
    required this.tiltStrength,
  });

  final List<_Glyph> glyphs;
  final List<_Bit> bits;
  final TextStyle baseStyle;
  final Duration now;
  final double textPad;
  final double scrollOffset;
  final Duration letterDuration;
  final double slideDistance;
  final TextDirection direction;
  final TextScaler scaler;
  final Locale? locale;
  final Color cursorColor;
  final double cursorWidth;
  final double caretTop;
  final double caretBottom;
  final double cursorX;
  final double trailX;
  final double cursorAlpha;
  final TextAnimationDelete deleteMode;
  final bool slideUp;
  final bool unblur;
  final bool pop;
  final bool tilt;
  final int popStrength;
  final int tiltStrength;

  double get _fontSize => baseStyle.fontSize ?? 15;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(0, textPad - scrollOffset);

    // The plugin clips letters and caret to the field, then draws the flying
    // bits outside that clip.
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    for (final glyph in glyphs) {
      final rect = glyph.rect;
      final painter = glyph.painter;
      if (rect == null || painter == null) continue;

      var opacity = 1.0;
      var dy = 0.0;
      var blurSigma = 0.0;
      var scale = 1.0;
      var rotate = 0.0;
      if (glyph.phase == _GlyphPhase.entering) {
        final p = ((now - glyph.started).inMicroseconds / letterDuration.inMicroseconds).clamp(0.0, 1.0);
        final eased = (1 - math.pow(1 - p, 3)).toDouble();
        final f = (pop || tilt
                ? 1 - math.pow(1 - math.min(1, p * 2.5), 3)
                : eased)
            .toDouble();
        opacity = f;
        if (slideUp) dy = (slideDistance * (1 - eased)).toDouble();
        if (unblur) blurSigma = (8 * (1 - f)).toDouble();
        if (pop) {
          final k = popStrength / 100;
          final from = math.max(0.02, 1 - 0.9 * k).toDouble();
          final u = p - 1;
          final backOut = 1 + (4 * k + 1) * u * u * u + 4 * k * u * u;
          scale = (from + (1 - from) * backOut).toDouble();
        }
        if (tilt) {
          rotate = ((-40 * math.pi / 180) *
                  (tiltStrength / 100) *
                  math.pow(1 - p, 1.2) *
                  math.cos(p * 3.5 * math.pi))
              .toDouble();
        }
      }
      if (opacity <= 0) continue;

      var drawing = painter;
      if (opacity < 1) {
        final color = baseStyle.color ?? const Color(0xFF000000);
        drawing = TextPainter(
          text: TextSpan(text: glyph.text, style: baseStyle.copyWith(color: color.withValues(alpha: opacity))),
          textDirection: direction,
          textScaler: scaler,
          locale: locale,
        )..layout(maxWidth: glyph.width + 1);
      }

      final pos = rect.topLeft + origin;
      final cx = pos.dx + rect.width / 2;
      final cy = pos.dy + _fontSize * 0.49;
      canvas.save();
      canvas.translate(cx, cy);
      if (rotate != 0) canvas.rotate(rotate);
      if (scale != 1) canvas.scale(scale, scale);
      canvas.translate(-cx, -cy);
      canvas.translate(0, dy);
      if (blurSigma > 0) {
        canvas.saveLayer(
          rect.inflate(12).shift(pos - rect.topLeft),
          Paint()..imageFilter = ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        );
      }
      drawing.paint(canvas, pos);
      if (blurSigma > 0) canvas.restore();
      canvas.restore();
      if (!identical(drawing, painter)) drawing.dispose();
    }

    if (caretBottom > caretTop && cursorAlpha > 0) {
      final half = math.max(1.0, cursorWidth / 2);
      final rect = Rect.fromLTRB(
        math.min(cursorX, trailX) - half,
        caretTop + origin.dy,
        math.max(cursorX, trailX) + half,
        caretBottom + origin.dy,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(half)),
        Paint()..color = cursorColor.withValues(alpha: cursorAlpha),
      );
    }
    canvas.restore();

    for (final bit in bits) {
      final t = (now - bit.born).inMilliseconds / bit.life.inMilliseconds;
      if (t >= 1) continue;
      final alpha = (1 - t * t).clamp(0.0, 1.0).toDouble();
      final color = bit.color.withValues(alpha: alpha);
      final at = Offset(bit.x, bit.y) + origin;
      if (bit.text != null) {
        final painter = TextPainter(
          text: TextSpan(text: bit.text, style: baseStyle.copyWith(color: color)),
          textDirection: direction,
          textScaler: scaler,
          locale: locale,
        )..layout();
        final pivot = Offset(at.dx + painter.width / 2, at.dy - _fontSize * 0.33);
        canvas.save();
        canvas.translate(pivot.dx, pivot.dy);
        canvas.rotate(bit.angle);
        canvas.translate(-pivot.dx, -pivot.dy);
        painter.paint(canvas, at);
        canvas.restore();
        painter.dispose();
      } else {
        canvas.drawCircle(at, bit.size * (1 - t * 0.5), Paint()..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.now != now ||
      oldDelegate.scrollOffset != scrollOffset ||
      oldDelegate.textPad != textPad ||
      oldDelegate.cursorX != cursorX ||
      oldDelegate.trailX != trailX ||
      oldDelegate.caretTop != caretTop ||
      oldDelegate.caretBottom != caretBottom ||
      oldDelegate.cursorAlpha != cursorAlpha ||
      oldDelegate.bits.length != bits.length ||
      oldDelegate.deleteMode != deleteMode ||
      oldDelegate.slideUp != slideUp ||
      oldDelegate.unblur != unblur ||
      oldDelegate.pop != pop ||
      oldDelegate.tilt != tilt ||
      !identical(oldDelegate.glyphs, glyphs);
}
