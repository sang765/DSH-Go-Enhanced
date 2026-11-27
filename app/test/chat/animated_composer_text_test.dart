import 'package:dsh_app/performance/performance_state.dart';
import 'package:dsh_app/ui/chat/animated_composer_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(TextEditingController controller, {int maxLines = 6}) => MaterialApp(
  home: Scaffold(
    body: SizedBox(
      width: 300,
      height: 80,
      child: AnimatedComposerText(
        controller: controller,
        style: const TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF000000)),
        textPad: 4,
        maxLines: maxLines,
        textDirection: TextDirection.ltr,
        cursorColor: const Color(0xFF0000FF),
      ),
    ),
  ),
);

void main() {
  testWidgets('new glyphs settle and deleted glyphs leave', (tester) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    await tester.pumpWidget(_host(input));

    input.text = 'ab';
    await tester.pump();
    final state = tester.state<AnimatedComposerTextState>(find.byType(AnimatedComposerText));
    expect(state.activeGlyphs, 2);
    await tester.pump(const Duration(milliseconds: 600));
    expect(state.activeGlyphs, 0);

    // A deleted letter becomes a falling particle; it no longer counts as a glyph.
    input.text = 'a';
    await tester.pump();
    expect(state.activeGlyphs, 0);
    expect(state.activeBits, 1);
    await tester.pump(const Duration(milliseconds: 700));
    expect(state.activeBits, 0);
  });

  testWidgets('glyph time advances by frame deltas, not cumulative ticker elapsed', (tester) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    await tester.pumpWidget(_host(input));
    final state = tester.state<AnimatedComposerTextState>(find.byType(AnimatedComposerText));

    input.text = 'ab';
    await tester.pump();
    expect(state.animationClock, Duration.zero);

    // Ticker reports 100/200/300 ms; the clock must advance 100 ms per frame.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.animationClock, const Duration(milliseconds: 300));
    expect(state.activeGlyphs, 2);
  });

  testWidgets('a new letter does not restart letters already settling', (tester) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    await tester.pumpWidget(_host(input));
    final state = tester.state<AnimatedComposerTextState>(find.byType(AnimatedComposerText));

    input.text = 'a';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    input.text = 'ab';
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // At 300 ms the first letter is still inside its 320 ms animation and the
    // second has only been running 200 ms: neither may be reset or cut short.
    expect(state.activeGlyphs, 2);
    // The second letter settles 320 ms after its own arrival, at 420 ms.
    await tester.pump(const Duration(milliseconds: 120));
    expect(state.activeGlyphs, 0);
  });

  testWidgets('the gliding cursor fades smoothly instead of blinking', (tester) async {
    final input = TextEditingController(text: 'abc');
    input.selection = const TextSelection.collapsed(offset: 3);
    addTearDown(input.dispose);
    await tester.pumpWidget(_host(input));
    final state = tester.state<AnimatedComposerTextState>(find.byType(AnimatedComposerText));

    input.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    // A 400 ms-old glide is still inside the plugin's 500 ms solid window.
    expect(state.drawnCursorAlpha, 1);
  });

  testWidgets('an edit in the middle only animates the new glyph', (tester) async {
    final input = TextEditingController(text: 'abc');
    addTearDown(input.dispose);
    await tester.pumpWidget(_host(input));
    final state = tester.state<AnimatedComposerTextState>(find.byType(AnimatedComposerText));
    await tester.pump(const Duration(milliseconds: 600));

    input.text = 'axbc';
    await tester.pump();
    expect(state.activeGlyphs, 1);
  });

  testWidgets('dust deletion spawns one cloud per letter', (tester) async {
    final input = TextEditingController(text: 'ab');
    addTearDown(input.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 80,
          child: AnimatedComposerText(
            controller: input,
            style: const TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF000000)),
            textPad: 4,
            maxLines: 6,
            textDirection: TextDirection.ltr,
            cursorColor: const Color(0xFF0000FF),
            deleteMode: TextAnimationDelete.dust,
          ),
        ),
      ),
    ));
    final state = tester.state<AnimatedComposerTextState>(find.byType(AnimatedComposerText));
    input.text = 'a';
    await tester.pump();
    expect(state.activeBits, 7);
    await tester.pump(const Duration(milliseconds: 700));
    expect(state.activeBits, 0);
  });

  testWidgets('IME composing shows text without a letter-by-letter animation', (tester) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    await tester.pumpWidget(_host(input));

    input.value = const TextEditingValue(text: 'nh', composing: TextRange(start: 0, end: 2));
    await tester.pump();
    final state = tester.state<AnimatedComposerTextState>(find.byType(AnimatedComposerText));
    expect(state.activeGlyphs, 0);
  });

  testWidgets('a draft past maxLines still lays out every glyph', (tester) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    await tester.pumpWidget(_host(input, maxLines: 2));
    final state = tester.state<AnimatedComposerTextState>(find.byType(AnimatedComposerText));

    final long = 'a' * 120;
    input.text = long;
    await tester.pump();

    expect(state.laidOutGlyphs, long.length);
  });

  testWidgets('a caret after a newline targets the line below', (tester) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    await tester.pumpWidget(_host(input));
    final state = tester.state<AnimatedComposerTextState>(find.byType(AnimatedComposerText));

    input.text = 'abc';
    input.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();
    final firstLineTop = state.caretTargetTop;

    input.text = 'abc\ndef';
    input.selection = const TextSelection.collapsed(offset: 4);
    await tester.pump();

    expect(state.caretTargetTop, greaterThan(firstLineTop));
  });

  testWidgets('a trailing newline targets the empty line below', (tester) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    await tester.pumpWidget(_host(input));
    final state = tester.state<AnimatedComposerTextState>(find.byType(AnimatedComposerText));

    input.text = 'abc';
    input.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();
    final firstLineTop = state.caretTargetTop;

    input.text = 'abc\n';
    input.selection = const TextSelection.collapsed(offset: 4);
    await tester.pump();

    expect(state.caretTargetTop, greaterThan(firstLineTop));
    expect(state.caretTargetX, 0);
  });

  testWidgets('a trailing newline in RTL anchors to the leading edge', (tester) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 80,
          child: AnimatedComposerText(
            controller: input,
            style: const TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF000000)),
            textPad: 4,
            maxLines: 6,
            textDirection: TextDirection.rtl,
            cursorColor: const Color(0xFF0000FF),
          ),
        ),
      ),
    ));
    final state = tester.state<AnimatedComposerTextState>(find.byType(AnimatedComposerText));

    input.text = 'אב';
    input.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump();
    final firstLineTop = state.caretTargetTop;

    input.text = 'אב\n';
    input.selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();

    expect(state.caretTargetTop, greaterThan(firstLineTop));
    expect(state.caretTargetX, greaterThan(0));
  });

  testWidgets('moving the selection glides the caret without animating glyphs', (tester) async {
    final input = TextEditingController(text: 'abc');
    addTearDown(input.dispose);
    await tester.pumpWidget(_host(input));
    final state = tester.state<AnimatedComposerTextState>(find.byType(AnimatedComposerText));
    expect(state.activeGlyphs, 0);

    input.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump();
    expect(state.activeGlyphs, 0);
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
  });
}
