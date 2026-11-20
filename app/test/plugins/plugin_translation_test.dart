import 'dart:async';

import 'package:dsh_app/state/plugin_translation_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only Han text in an English UI gets the translate action', () {
    expect(pluginNeedsTranslation('好感度里程碑邀请', 'en'), isTrue);
    expect(pluginNeedsTranslation('好感度里程碑邀请', 'en-US'), isTrue);
    expect(pluginNeedsTranslation('好感度里程碑邀请', 'zh'), isFalse);
    expect(pluginNeedsTranslation('Affection Milestone', 'en'), isFalse);
  });

  test('translations are cached; a failure keeps the original', () async {
    var calls = 0;
    final container = ProviderContainer(
      overrides: [
        myMemoryTranslatorProvider.overrideWithValue((text, {required from, required to}) async {
          calls++;
          if (text == '坏') throw StateError('offline');
          return 'Translated $text';
        }),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(pluginTranslationProvider.notifier);

    await notifier.translate('好', from: 'zh-CN', to: 'en');
    expect(container.read(pluginTranslationProvider).of('好'), 'Translated 好');
    await notifier.translate('好', from: 'zh-CN', to: 'en');
    expect(calls, 1);

    await notifier.translate('坏', from: 'zh-CN', to: 'en');
    expect(container.read(pluginTranslationProvider).hasFailed('坏'), isTrue);
    expect(container.read(pluginTranslationProvider).of('坏'), isNull);
  });

  test('a request in flight is pending and clears when it finishes', () async {
    final gate = Completer<String>();
    final container = ProviderContainer(
      overrides: [
        myMemoryTranslatorProvider.overrideWithValue(
          (text, {required from, required to}) => gate.future,
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(pluginTranslationProvider.notifier);
    final done = notifier.translate('好', from: 'zh-CN', to: 'en');
    expect(container.read(pluginTranslationProvider).isPending('好'), isTrue);
    gate.complete('Good');
    await done;
    expect(container.read(pluginTranslationProvider).isPending('好'), isFalse);
    expect(container.read(pluginTranslationProvider).of('好'), 'Good');
  });
}
