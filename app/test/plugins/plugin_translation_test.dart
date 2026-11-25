import 'dart:async';

import 'package:dsh_app/state/plugin_translation_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only Han text in an English UI gets the translate action', () {
    expect(pluginNeedsTranslation('好感度里程碑邀请', 'en'), isTrue);
    expect(pluginNeedsTranslation('好感度里程碑邀请', 'en-US'), isTrue);
    expect(pluginNeedsTranslation('好感度里程碑邀请', 'zh'), isFalse);
    expect(pluginNeedsTranslation('Affection Milestone', 'en'), isFalse);
  });

  test('translations are cached by locale; a failure keeps the original', () async {
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
    expect(container.read(pluginTranslationProvider).of('好', to: 'en'), 'Translated 好');
    // An English copy must not be shown when the UI is Chinese.
    expect(container.read(pluginTranslationProvider).of('好', to: 'zh'), isNull);
    await notifier.translate('好', from: 'zh-CN', to: 'en');
    expect(calls, 1);

    await notifier.translate('坏', from: 'zh-CN', to: 'en');
    expect(container.read(pluginTranslationProvider).hasFailed('坏', to: 'en'), isTrue);
    expect(container.read(pluginTranslationProvider).of('坏', to: 'en'), isNull);
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
    expect(container.read(pluginTranslationProvider).isPending('好', to: 'en'), isTrue);
    gate.complete('Good');
    await done;
    expect(container.read(pluginTranslationProvider).isPending('好', to: 'en'), isFalse);
    expect(container.read(pluginTranslationProvider).of('好', to: 'en'), 'Good');
  });

  test('translating to a second locale keeps a separate cache entry', () async {
    final container = ProviderContainer(
      overrides: [
        myMemoryTranslatorProvider.overrideWithValue(
          (text, {required from, required to}) async => '$to:$text',
        ),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(pluginTranslationProvider.notifier);

    await notifier.translate('好', from: 'zh-CN', to: 'en');
    await notifier.translate('好', from: 'zh-CN', to: 'ja');
    final state = container.read(pluginTranslationProvider);
    expect(state.of('好', to: 'en'), 'en:好');
    expect(state.of('好', to: 'ja'), 'ja:好');
    // A locale that was never requested must not inherit either copy.
    expect(state.of('好', to: 'zh'), isNull);
    expect(state.cache.length, 2);
  });

  test('pending and failed are scoped to the target locale', () async {
    final gate = Completer<String>();
    final container = ProviderContainer(
      overrides: [
        myMemoryTranslatorProvider.overrideWithValue((text, {required from, required to}) async {
          if (to == 'fr') throw StateError('offline');
          return gate.future;
        }),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(pluginTranslationProvider.notifier);

    final done = notifier.translate('好', from: 'zh-CN', to: 'en');
    var state = container.read(pluginTranslationProvider);
    expect(state.isPending('好', to: 'en'), isTrue);
    expect(state.isPending('好', to: 'zh'), isFalse);

    // A failure in one locale does not block or mark the in-flight one.
    await notifier.translate('好', from: 'zh-CN', to: 'fr');
    state = container.read(pluginTranslationProvider);
    expect(state.hasFailed('好', to: 'fr'), isTrue);
    expect(state.hasFailed('好', to: 'en'), isFalse);

    gate.complete('Good');
    await done;
    state = container.read(pluginTranslationProvider);
    expect(state.isPending('好', to: 'en'), isFalse);
    expect(state.hasFailed('好', to: 'en'), isFalse);
    expect(state.of('好', to: 'en'), 'Good');
    expect(state.hasFailed('好', to: 'fr'), isTrue);
    expect(state.of('好', to: 'fr'), isNull);
  });
}
