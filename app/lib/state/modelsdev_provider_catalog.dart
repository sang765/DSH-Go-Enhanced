// The models.dev provider catalogue, fetched when the add-provider sheet opens:
// one GET of https://models.dev/api.json (about 7 MB), parsed into the fields
// the add-provider flow needs. Cached in memory for the session. Logo of a
// provider: https://models.dev/logos/<id>.svg.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpException;

import 'package:dsh_client/dsh_client.dart' show piAiThinkingLevels, ProviderApi;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../update/update_http.dart';
import 'providers_state.dart';

const _catalogUrl = 'https://models.dev/api.json';
const _logoBase = 'https://models.dev/logos';

/// Models the adapter can declare; anything else in a listing's modality
/// report (audio, video) is dropped, like the engine's own discovery filter.
const _knownModalities = {'text', 'image'};

/// One provider of the catalogue.
class ModelsDevProvider {
  const ModelsDevProvider({required this.id, required this.name, this.apiUrl, this.doc, this.models = const []});

  final String id;

  /// Display name as models.dev spells it (「DeepSeek」, 「302.AI」).
  final String name;

  /// The API base models.dev advertises; null means the site does not list
  /// one and the Base URL field stays editable.
  final String? apiUrl;

  /// Documentation link, opened from the form's preset note.
  final String? doc;
  final List<ModelsDevModel> models;

  /// `https://models.dev/logos/<id>.svg`.
  String get logoUrl => '$_logoBase/$id.svg';
}

/// One model of a catalogue provider.
class ModelsDevModel {
  const ModelsDevModel({
    required this.id,
    required this.name,
    this.contextWindow,
    this.maxTokens,
    this.input,
    this.reasoningEfforts = const [],
    this.reasons = false,
  });

  final String id;
  final String name;
  final int? contextWindow;
  final int? maxTokens;

  /// `text` / `image`; null means the listing says nothing.
  final List<String>? input;

  /// Thinking levels from `reasoning_options`, mapped onto the adapter's
  /// levels; empty when the model offers none this client can declare.
  final List<String> reasoningEfforts;

  /// What the listing says about reasoning, kept for the picker's badge.
  final bool reasons;
}

/// The protocol the form offers for a catalogue provider, read off the API
/// base models.dev advertises: an Anthropic-shaped endpoint speaks messages,
/// everything else is OpenAI-compatible (the site's dominant listing).
ProviderApi protocolOf(ModelsDevProvider provider) =>
    provider.apiUrl != null && provider.apiUrl!.contains('anthropic')
    ? ProviderApi.anthropicMessages
    : ProviderApi.openaiCompletions;

/// `api.json` → catalogue. Sorted by display name; providers without any
/// model stay (a few are credential-forwarding gateways) — the form works
/// with a hand-added model just the same.
ModelsDevCatalog parseModelsDevCatalog(Object? json) {
  final root = json is Map ? json : const {};
  final providers = <ModelsDevProvider>[];
  for (final entry in root.entries) {
    final id = entry.key;
    if (id is! String || id.isEmpty) continue;
    final raw = entry.value;
    if (raw is! Map) continue;
    final name = raw['name'];
    final rawModels = raw['models'];
    final models = <ModelsDevModel>[];
    if (rawModels is Map) {
      for (final modelEntry in rawModels.entries) {
        final model = _parseModel(modelEntry.key, modelEntry.value);
        if (model != null) models.add(model);
      }
    }
    final api = raw['api'];
    providers.add(
      ModelsDevProvider(
        id: id,
        name: name is String && name.trim().isNotEmpty ? name.trim() : id,
        apiUrl: api is String && api.trim().isNotEmpty ? api.trim() : null,
        doc: raw['doc'] is String ? raw['doc'] as String : null,
        models: models,
      ),
    );
  }
  providers.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return ModelsDevCatalog(providers);
}

ModelsDevModel? _parseModel(Object? rawId, Object? raw) {
  if (raw is! Map) return null;
  final id = rawId is String && rawId.trim().isNotEmpty ? rawId.trim() : null;
  if (id == null) return null;
  final name = raw['name'];
  final limit = raw['limit'];
  final modalities = raw['modalities'];
  final input = modalities is Map ? modalities['input'] : null;
  final efforts = _effortsOf(raw['reasoning'], raw['reasoning_options']);
  return ModelsDevModel(
    id: id,
    name: name is String && name.trim().isNotEmpty ? name.trim() : id,
    contextWindow: limit is Map ? _asInt(limit['context']) : null,
    maxTokens: limit is Map ? _asInt(limit['output']) : null,
    input: input is List
        ? [for (final m in input) if (m is String && _knownModalities.contains(m)) m]
        : null,
    reasoningEfforts: efforts,
    reasons: raw['reasoning'] == true || efforts.isNotEmpty,
  );
}

int? _asInt(Object? value) => value is int ? value : (value is num ? value.toInt() : null);

/// `reasoning_options` → the adapter's thinking levels. An `effort` block
/// lists the wire values (`low`…`max`); `none` maps to `off`, which the
/// adapter offers implicitly and the map must not carry. `budget_tokens`
/// models keep no levels here (the model page can declare them by hand);
/// a model that only reasons as a toggle keeps `low`, matching the
/// engine's own discovery of such gateways.
List<String> _effortsOf(Object? reasoning, Object? options) {
  if (options is! List) return reasoning == true ? const ['low'] : const [];
  final values = <String>[];
  for (final block in options) {
    if (block is! Map || block['type'] != 'effort') continue;
    final raw = block['values'];
    if (raw is! List) continue;
    values.addAll([for (final v in raw) if (v is String) v]);
  }
  return [
    for (final value in values)
      if (value != 'none' && piAiThinkingLevels.contains(value)) value,
  ];
}

class ModelsDevCatalog {
  const ModelsDevCatalog(this.providers);

  final List<ModelsDevProvider> providers;

  static final ModelsDevCatalog empty = ModelsDevCatalog(const []);
}

/// The HTTP seam, injectable for tests.
final modelsDevHttpProvider = Provider<UpdateHttp>((ref) => IoUpdateHttp());

/// Loads the catalogue, session-cached. `keepAlive`: the sheet reopens far
/// more often than the site changes; a pull is also cheap to refresh by
/// reopening after a failure (the retry button re-runs the future).
final modelsDevCatalogProvider = AsyncNotifierProvider<ModelsDevCatalogNotifier, ModelsDevCatalog>(
  ModelsDevCatalogNotifier.new,
);

class ModelsDevCatalogNotifier extends AsyncNotifier<ModelsDevCatalog> {
  @override
  Future<ModelsDevCatalog> build() async {
    final http = ref.watch(modelsDevHttpProvider);
    final response = await http.get(
      Uri.parse(_catalogUrl),
      headers: const {'Accept': 'application/json'},
      timeout: const Duration(seconds: 30),
    );
    if (response.status != 200) {
      await response.discard();
      throw HttpException('models.dev responded ${response.status}');
    }
    final text = await response.text(maxBytes: 16 * 1024 * 1024, timeout: const Duration(seconds: 30));
    // Off the UI thread: parsing 7 MB of JSON is a visible hitch on a phone.
    return compute(_decode, text);
  }

  static ModelsDevCatalog _decode(String text) => parseModelsDevCatalog(jsonDecode(text));
}
