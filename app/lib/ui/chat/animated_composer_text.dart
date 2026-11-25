// SPDX-FileCopyrightText: 2026 CikeSeven
// SPDX-License-Identifier: MIT
// See THIRD_PARTY_NOTICES.md.
//
// Paints the composer's draft over a transparent EditableText. The real field
// keeps IME, selection, scrolling and key handling; this layer only draws
// glyphs that just arrived or are leaving. Nothing here edits the controller.

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/motion.dart';

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

  /// Number of glyphs still moving; used by tests to check that a batch ends.
  @visibleForTesting
  int get activeGlyphs => _glyphs.where((g) => g.phase != _GlyphPhase.steady).length;

  bool get _active => _glyphs.any((g) => g.phase != _GlyphPhase.steady);

  @override
  void initState() {
    super.initState();
    _text = widget.controller.text;
    _diff();
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
    for (final glyph in _glyphs) {
      glyph.painter?.dispose();
    }
    super.dispose();
  }

  void _onController() {
    if (!mounted) return;
    final text = widget.controller.text;
    if (text == _text) return;
    setState(() {
      _text = text;
      _diff();
      _relayout();
    });
    if (_active) _ticker.start();
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
        final glyph = _Glyph(_nextId++, cluster, composing ? _GlyphPhase.steady : _GlyphPhase.entering, _now);
        glyph.batchIndex = created.clamp(0, AppMotion.staggerLimit);
        created++;
        next.add(glyph);
      }
    }

    final kept = next.map((g) => g.id).toSet();
    for (final glyph in oldById.values) {
      if (glyph.phase == _GlyphPhase.exiting || kept.contains(glyph.id) || composing) continue;
      glyph
        ..phase = _GlyphPhase.exiting
        ..started = _now;
      next.add(glyph);
    }
    // A deleted glyph keeps its old box while it falls away: the rest of the
    // line has already moved on, which is exactly what a falling letter wants.
    for (final glyph in alreadyLeaving) {
      if (!glyph.remove && _now - glyph.started < widget.deleteDuration) next.add(glyph);
    }
    _glyphs
      ..clear()
      ..addAll(next);
  }

  void _relayout() {
    if (_width <= 0) return;
    final scaler = MediaQuery.textScalerOf(context);
    final whole = TextPainter(
      text: TextSpan(text: _text, style: widget.style),
      textDirection: widget.textDirection,
      maxLines: widget.maxLines,
      textScaler: scaler,
      locale: widget.locale,
    )..layout(maxWidth: _width);

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
    whole.dispose();
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
    if (!_active) _ticker.stop();
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

      if (glyph.phase == _GlyphPhase.entering) {
        // Only the first [AppMotion.staggerLimit] letters of a batch wait;
        // pasting a page must not take a second to finish.
        final start = glyph.batchIndex * AppMotion.stagger.inMilliseconds;
        final local = ((elapsedMs - start) / letterDuration.inMilliseconds).clamp(0.0, 1.0);
        final eased = Curves.easeOut.transform(local);
        opacity = eased;
        dy = (1 - eased) * slideDistance;
        scale = 0.9 + 0.1 * AppMotion.popCurve.transform(local);
        rotate = (1 - eased) * 0.08 * (glyph.id.isEven ? 1 : -1);
      } else if (glyph.phase == _GlyphPhase.exiting) {
        opacity = 1 - p;
        dy = p * p * 18;
        dx = (glyph.id % 3 - 1) * p * 6;
        scale = 1 - 0.2 * p;
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
      painter.paint(canvas, pos);
      canvas.restore();
      if (!identical(painter, cached)) painter.dispose();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) =>
      oldDelegate.now != now ||
      oldDelegate.scrollOffset != scrollOffset ||
      oldDelegate.textPad != textPad ||
      !identical(oldDelegate.glyphs, glyphs);
}
