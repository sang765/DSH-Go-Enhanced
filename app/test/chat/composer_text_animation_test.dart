import 'package:dsh_app/performance/performance_state.dart';
import 'package:dsh_app/ui/chat/animated_composer_text.dart';
import 'package:dsh_app/ui/chat/composer.dart';
import 'package:dsh_app/ui/theme/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

class _AnimationOn extends PerformancePrefsController {
  @override
  PerformancePrefs build() => const PerformancePrefs(textAnimation: true);
}

class _AnimationConfigured extends PerformancePrefsController {
  @override
  PerformancePrefs build() => const PerformancePrefs(
    textAnimation: true,
    textAnimationSpeed: 480,
    textAnimationSlide: 20,
    textAnimationDelete: TextAnimationDelete.dust,
    textAnimationCursor: TextAnimationCursor.steady,
    textAnimationLetters: false,
    textAnimationSlideUp: false,
    textAnimationUnblur: true,
    textAnimationPop: true,
    textAnimationTilt: true,
    textAnimationTrail: false,
    textAnimationCursorSpeed: 30,
  );
}

Widget _composer(TextEditingController input) => Scaffold(
  body: Composer(
    controller: input,
    connected: true,
    running: false,
    onSend: () {},
    onStop: () {},
  ),
);

void main() {
  testWidgets('the effect is off unless asked for and the fluid tier is on', (tester) async {
    final input = TextEditingController(text: 'hello');
    addTearDown(input.dispose);
    await tester.pumpWidget(testApp(_composer(input)));

    expect(tester.widget<TextField>(find.byType(TextField)).style?.color, isNot(Colors.transparent));
    expect(tester.widget<TextField>(find.byType(TextField)).showCursor, isTrue);
    expect(find.byType(AnimatedComposerText), findsNothing);
  });

  testWidgets('fluid plus the opt-in pref paints over a transparent field', (tester) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    await tester.pumpWidget(
      testApp(
        AppMotionScope(fluid: true, child: _composer(input)),
        overrides: [performancePrefsProvider.overrideWith(() => _AnimationOn())],
      ),
    );

    expect(tester.widget<TextField>(find.byType(TextField)).style?.color, Colors.transparent);
    expect(tester.widget<TextField>(find.byType(TextField)).showCursor, isFalse);
    expect(find.byType(AnimatedComposerText), findsOneWidget);

    input.text = 'abc';
    await tester.pump();
    expect(input.text, 'abc');
  });

  testWidgets('the configured speed, slide, delete and cursor reach the overlay', (tester) async {
    final input = TextEditingController();
    addTearDown(input.dispose);
    await tester.pumpWidget(
      testApp(
        AppMotionScope(fluid: true, child: _composer(input)),
        overrides: [performancePrefsProvider.overrideWith(() => _AnimationConfigured())],
      ),
    );

    final overlay = tester.widget<AnimatedComposerText>(find.byType(AnimatedComposerText));
    expect(overlay.letterDuration, const Duration(milliseconds: 480));
    expect(overlay.slideDistance, 20);
    expect(overlay.deleteMode, TextAnimationDelete.dust);
    expect(overlay.cursorMode, TextAnimationCursor.steady);
    expect(overlay.animateLetters, isFalse);
    expect(overlay.slideUp, isFalse);
    expect(overlay.unblur, isTrue);
    expect(overlay.pop, isTrue);
    expect(overlay.tilt, isTrue);
    expect(overlay.trailEnabled, isFalse);
    expect(overlay.cursorSpeed, 30);
  });
}
