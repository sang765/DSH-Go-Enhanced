// What makes the shared UI feel at home on iOS, plus the sheet recede now shared
// with Android. Everything else stays as it was.

import 'package:dsh_app/ui/common/app_sheet.dart';
import 'package:dsh_app/ui/common/overscroll_forwarder.dart';
import 'package:dsh_app/ui/theme/app_theme.dart';
import 'package:dsh_app/ui/theme/motion.dart';
import 'package:dsh_app/ui/theme/sheet_recede.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_test/flutter_test.dart';

const _page = Key('page');
const _open = Key('open');
const _push = Key('push');
const _pop = Key('pop');
const _stack = Key('stack');

const _screen = 400.0;
const _statusBar = 59.0;

Widget _app({required bool fluid}) => MaterialApp(
  theme: buildLightTheme(),
  builder: (context, child) => AppMotionScope(fluid: fluid, child: child!),
  // Every page says what the status bar should be.
  home: AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      key: _page,
      body: Builder(
        builder: (context) => Center(
          child: TextButton(
            key: _open,
            onPressed: () => showAppSheet<void>(
              context,
              builder: (_) => Column(
                children: [
                  const SizedBox(height: 240),
                  TextButton(
                    key: _stack,
                    onPressed: () => showAppSheet<void>(
                      context,
                      builder: (_) => const SizedBox(height: 200),
                    ),
                    child: const Text('stack'),
                  ),
                  TextButton(
                    key: _push,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => Scaffold(
                          body: Center(
                            child: TextButton(
                              key: _pop,
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('back'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('push'),
                  ),
                ],
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  void useScreen(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(_screen, 800);
    tester.view.padding = const FakeViewPadding(top: _statusBar);
    tester.view.viewPadding = const FakeViewPadding(top: _statusBar);
    addTearDown(tester.view.reset);
  }

  testWidgets('a press is a highlight on iOS, with no ripple', (tester) async {
    expect(buildLightTheme().splashFactory, NoSplash.splashFactory);
    expect(buildDarkTheme().splashFactory, NoSplash.splashFactory);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('type isn\'t tracked for Roboto on iOS', (tester) async {
    final text = buildLightTheme().textTheme;
    expect(text.bodyLarge?.letterSpacing, 0);
    expect(text.bodyMedium?.letterSpacing, 0);
    expect(text.labelLarge?.letterSpacing, 0);
    expect(text.headlineMedium?.letterSpacing, lessThan(0));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('other platforms keep their tracking', (tester) async {
    expect(buildLightTheme().textTheme.bodyMedium?.letterSpacing, isNot(0));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the adaptive switch drops the check mark on iOS and keeps the colours', (tester) async {
    final theme = buildLightTheme();
    final adapted = theme.getAdaptation<SwitchThemeData>()!.adapt(theme, theme.switchTheme);
    expect(adapted.thumbIcon, isNull);
    expect(adapted.trackColor, same(theme.switchTheme.trackColor));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the switch theme stays as it is elsewhere', (tester) async {
    final theme = buildLightTheme();
    expect(theme.getAdaptation<SwitchThemeData>()!.adapt(theme, theme.switchTheme), same(theme.switchTheme));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('other platforms keep their ripple', (tester) async {
    expect(buildLightTheme().splashFactory, isNot(NoSplash.splashFactory));
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('a drag past the end of an inner scroller moves the list around it', (tester) async {
    useScreen(tester);
    final outer = ScrollController();
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: outer,
            children: [
              SizedBox(
                height: 200,
                child: OverscrollForwarder(
                  child: SingleChildScrollView(
                    key: const Key('inner'),
                    child: Container(height: 210, color: const Color(0xFFEEEEEE)),
                  ),
                ),
              ),
              const SizedBox(height: 2000),
            ],
          ),
        ),
      ),
    );
    await tester.drag(find.byKey(const Key('inner')), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(outer.offset, greaterThan(50));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the page sits back while a sheet is up, and comes back whole', (tester) async {
    useScreen(tester);
    await tester.pumpWidget(_app(fluid: true));
    await tester.pump();
    expect(tester.getRect(find.byKey(_page)).width, _screen);
    final page = tester.state(find.byKey(_page));

    await tester.tap(find.byKey(_open));
    await tester.pumpAndSettle();
    final back = tester.getRect(find.byKey(_page));
    expect(back.width, closeTo(_screen * SheetRecede.scale, 0.5));
    // Its top edge lands under the status bar, whose text stays on the dark.
    expect(back.top, closeTo(_statusBar, 0.5));

    await tester.tapAt(const Offset(_screen / 2, 40));
    await tester.pumpAndSettle();
    await tester.pump();
    expect(SheetRecede.amount.value, 0);
    expect(tester.getRect(find.byKey(_page)).width, _screen);
    expect(tester.state(find.byKey(_page)), same(page));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('closing the sheet animates the page back instead of snapping', (tester) async {
    useScreen(tester);
    await tester.pumpWidget(_app(fluid: true));
    await tester.pump();
    await tester.tap(find.byKey(_open));
    await tester.pumpAndSettle();
    expect(SheetRecede.amount.value, 1);

    // The route stops being current the moment the pop starts. The page must
    // still follow the sheet's reverse animation, not jump back in one frame.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    var sawIntermediate = false;
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      final value = SheetRecede.amount.value;
      if (value > 0 && value < 1) sawIntermediate = true;
    }
    expect(sawIntermediate, isTrue);

    await tester.pumpAndSettle();
    expect(SheetRecede.amount.value, 0);
    expect(tester.getRect(find.byKey(_page)).width, _screen);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('pushing a screen from a sheet brings the page back, and popping restores the recede',
      (tester) async {
    useScreen(tester);
    await tester.pumpWidget(_app(fluid: true));
    await tester.pump();
    await tester.tap(find.byKey(_open));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_page)).width, closeTo(_screen * SheetRecede.scale, 0.5));

    await tester.tap(find.byKey(_push));
    await tester.pumpAndSettle();
    expect(SheetRecede.amount.value, 0);

    await tester.tap(find.byKey(_pop));
    await tester.pumpAndSettle();
    expect(SheetRecede.amount.value, 1);
    expect(tester.getRect(find.byKey(_page)).width, closeTo(_screen * SheetRecede.scale, 0.5));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a sheet sits back while another is stacked on top of it', (tester) async {
    useScreen(tester);
    await tester.pumpWidget(_app(fluid: true));
    await tester.pump();
    await tester.tap(find.byKey(_open));
    await tester.pumpAndSettle();

    final lower = find.byType(SheetRecedeSheet).first;
    expect(tester.getRect(lower).width, _screen);

    await tester.tap(find.byKey(_stack));
    await tester.pumpAndSettle();
    expect(tester.getRect(lower).width, closeTo(_screen * SheetRecede.coveredScale, 0.5));

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(tester.getRect(lower).width, _screen);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the status bar turns light over the dark edge, and back', (tester) async {
    useScreen(tester);
    await tester.pumpWidget(_app(fluid: true));
    await tester.pump();

    Brightness? statusBar() => tester.binding.renderViews.first.debugLayer!
        .find<SystemUiOverlayStyle>(const Offset(_screen / 2, _statusBar))
        ?.statusBarBrightness;

    expect(statusBar(), SystemUiOverlayStyle.dark.statusBarBrightness);

    await tester.tap(find.byKey(_open));
    await tester.pumpAndSettle();
    expect(statusBar(), SystemUiOverlayStyle.light.statusBarBrightness);

    await tester.tapAt(const Offset(_screen / 2, 100));
    await tester.pumpAndSettle();
    await tester.pump();
    expect(statusBar(), SystemUiOverlayStyle.dark.statusBarBrightness);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('off the fluid tier the page stays where it is', (tester) async {
    useScreen(tester);
    await tester.pumpWidget(_app(fluid: false));
    await tester.tap(find.byKey(_open));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_page)).width, _screen);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('on Android the page sits back while a sheet is up too', (tester) async {
    useScreen(tester);
    await tester.pumpWidget(_app(fluid: true));
    await tester.pump();
    expect(tester.getRect(find.byKey(_page)).width, _screen);

    await tester.tap(find.byKey(_open));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(_page)).width, closeTo(_screen * SheetRecede.scale, 0.5));

    await tester.tapAt(const Offset(_screen / 2, 100));
    await tester.pumpAndSettle();
    expect(SheetRecede.amount.value, 0);
    expect(tester.getRect(find.byKey(_page)).width, _screen);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
