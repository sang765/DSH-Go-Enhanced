// The models.dev catalogue parser and the add-provider sheet's preset flow:
// wire shapes → catalogue fields, protocol guessing, effort levels, and the
// form locking the preset fields.

import 'dart:convert';

import 'package:dsh_app/state/modelsdev_provider_catalog.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _provider({
  String name = 'Example',
  String? api = 'https://api.example.com/v1',
  String npm = '@ai-sdk/openai-compatible',
  Map<String, Object?> models = const {},
  String? doc,
}) => {
  'id': 'example',
  'name': name,
  'npm': npm,
  'api': ?api,
  'doc': ?doc,
  'env': ['EXAMPLE_API_KEY'],
  'models': models,
};

Map<String, Object?> _model({
  String name = 'Example Pro',
  int? context = 131072,
  int? output = 65536,
  List<String>? input = const ['text', 'image'],
  bool reasoning = true,
  List<Object?>? options = const [
    {'type': 'effort', 'values': ['low', 'medium', 'high']},
  ],
}) => {
  'id': 'example-pro',
  'name': name,
  'reasoning': reasoning,
  'tool_call': true,
  'limit': {'context': ?context, 'output': ?output},
  'modalities': {
    'input': ?input,
    'output': ['text'],
  },
  'reasoning_options': ?options,
};

ModelsDevCatalog _catalog({required Map<String, Object?> providers}) =>
    parseModelsDevCatalog(jsonDecode(jsonEncode(providers)));

void main() {
  test('parses providers sorted by display name with api base and models', () {
    final catalog = _catalog(
      providers: {
        'zeta': _provider(name: 'Zeta AI', models: {'m1': _model()}),
        'alpha': _provider(name: 'alpha cloud', models: {'m1': _model()}, api: null),
      },
    );
    expect(catalog.providers, hasLength(2));
    expect(catalog.providers[0].name, 'alpha cloud');
    expect(catalog.providers[0].id, 'alpha');
    expect(catalog.providers[0].apiUrl, isNull);
    expect(catalog.providers[0].logoUrl, 'https://models.dev/logos/alpha.svg');
    expect(catalog.providers[1].name, 'Zeta AI');
    expect(catalog.providers[1].apiUrl, 'https://api.example.com/v1');
    expect(catalog.providers[1].models.single.name, 'Example Pro');
    expect(catalog.providers[1].models.single.contextWindow, 131072);
    expect(catalog.providers[1].models.single.maxTokens, 65536);
    expect(catalog.providers[1].models.single.input, ['text', 'image']);
  });

  test('protocol: an anthropic API base speaks messages, others OpenAI', () {
    final catalog = _catalog(
      providers: {
        'anthropic-like': _provider(npm: '@ai-sdk/anthropic', api: 'https://api.minimax.io/anthropic/v1'),
        'plain': _provider(npm: '@ai-sdk/openai-compatible'),
        'openai': _provider(npm: '@ai-sdk/openai'),
      },
    );
    expect(protocolOf(catalog.providers[0]), ProviderApi.anthropicMessages);
    expect(protocolOf(catalog.providers[1]), ProviderApi.openaiCompletions);
    expect(protocolOf(catalog.providers[2]), ProviderApi.openaiCompletions);
  });

  test('effort values map onto the adapter levels, none and unknown drop', () {
    final catalog = _catalog(
      providers: {
        'a': _provider(models: {
          'm': _model(options: [
            {'type': 'effort', 'values': ['none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max']},
          ]),
        }),
        'b': _provider(models: {
          'm': _model(options: [
            {'type': 'budget_tokens', 'min': 1024, 'max': 32000},
          ]),
        }),
        'c': _provider(models: {'m': _model(reasoning: false, options: null)}),
      },
    );
    expect(catalog.providers[0].models.single.reasoningEfforts, ['minimal', 'low', 'medium', 'high', 'xhigh', 'max']);
    // A budget-only model still reasons (the API says so) but offers no
    // level this client can declare.
    expect(catalog.providers[1].models.single.reasoningEfforts, isEmpty);
    expect(catalog.providers[1].models.single.reasons, isTrue);
    expect(catalog.providers[2].models.single.reasons, isFalse);
  });

  test('unknown modalities drop, keeping text and image', () {
    final catalog = _catalog(
      providers: {
        'a': _provider(models: {
          'm': _model(input: ['text', 'image', 'audio', 'video']),
        }),
      },
    );
    expect(catalog.providers[0].models.single.input, ['text', 'image']);
  });

  test('a model that reasons as a toggle keeps the low level', () {
    final catalog = _catalog(
      providers: {
        'a': _provider(models: {
          'm': _model(options: [
            {'type': 'toggle'},
          ]),
        }),
      },
    );
    // reasoning stays true → low, matching the engine's discovery of such
    // gateways; reasoning false → nothing.
    final toggled = _catalog(
      providers: {
        'a': _provider(models: {
          'm': _model(reasoning: true, options: [
            {'type': 'toggle'},
          ]),
        }),
      },
    );
    expect(toggled.providers[0].models.single.reasoningEfforts, ['low']);
    expect(catalog.providers[0].models.single.reasoningEfforts, isEmpty);
  });

  test('junk entries are skipped, missing names fall back to the id', () {
    final catalog = parseModelsDevCatalog({
      'good': {'name': 'Good', 'models': {'m': 'not-a-map'}},
      'noname': {'models': {}},
      'bad': 'not-a-map',
      42: {'name': 'No'},
    });
    expect(catalog.providers.map((p) => p.id), ['good', 'noname']);
    expect(catalog.providers[1].name, 'noname');
    expect(catalog.providers[0].models, isEmpty);
  });
}
