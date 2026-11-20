// On-demand translation of plugin metadata. A plugin ships its name and
// description in its own language (often Chinese only); the app does not
// rewrite that metadata, it offers a translated copy beside the original.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Translates one piece of metadata. [from] and [to] are language ids
/// (`zh-CN`, `en`). A seam so tests and other backends can replace it.
typedef PluginTextTranslator = Future<String> Function(
  String text, {
  required String from,
  required String to,
});

/// The free anonymous MyMemory endpoint. No key, no account; plugin metadata
/// is public and tiny. Failures throw so the caller keeps the original text.
final myMemoryTranslatorProvider = Provider<PluginTextTranslator>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return (text, {required from, required to}) async {
    final response = await client
        .get(
          Uri.https('api.mymemory.translated.net', '/get', {
            'q': text,
            'langpair': '$from|$to',
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw StateError('translation HTTP ${response.statusCode}');
    final data = jsonDecode(response.body);
    if (data is! Map) throw const FormatException('translation response');
    if (data['quotaFinished'] == true || data['responseStatus'] != 200) {
      throw StateError('translation unavailable');
    }
    final body = data['responseData'];
    final translated = body is Map ? body['translatedText'] : null;
    if (translated is! String || translated.trim().isEmpty) throw const FormatException('translation text');
    // MyMemory puts quota and length warnings in translatedText itself.
    if (translated.contains('MYMEMORY WARNING') || translated.contains('QUERY LENGTH LIMIT')) {
      throw StateError('translation unavailable');
    }
    return translated.trim();
  };
});

/// Han characters: the only text this feature offers to translate. Latin,
/// kana and Hangul are left alone — the app has no way to tell Japanese from
/// Chinese here, and the endpoint is a Chinese-to-English one.
final _han = RegExp(r'[\u3400-\u9fff]');

bool pluginNeedsTranslation(String text, String locale) =>
    locale.toLowerCase().startsWith('en') && _han.hasMatch(text);

/// The translated copies of metadata the person asked for, kept for the
/// session. Pending and failed are per text so one bad field never blocks
/// the other field's button.
@immutable
class PluginTranslationState {
  const PluginTranslationState({
    this.cache = const {},
    this.pending = const {},
    this.failed = const {},
  });

  final Map<String, String> cache;
  final Set<String> pending;
  final Set<String> failed;

  String? of(String text) => cache[text];
  bool isPending(String text) => pending.contains(text);
  bool hasFailed(String text) => failed.contains(text);
}

class PluginTranslation extends Notifier<PluginTranslationState> {
  @override
  PluginTranslationState build() => const PluginTranslationState();

  Future<void> translate(
    String text, {
    required String from,
    required String to,
  }) async {
    final current = state;
    if (text.isEmpty || current.cache.containsKey(text) || current.pending.contains(text)) return;
    state = PluginTranslationState(
      cache: current.cache,
      pending: {...current.pending, text},
      failed: {...current.failed}..remove(text),
    );
    try {
      final result = await ref.read(myMemoryTranslatorProvider)(text, from: from, to: to);
      final now = state;
      state = PluginTranslationState(
        cache: result.trim().isNotEmpty && result.trim() != text.trim()
            ? {...now.cache, text: result}
            : now.cache,
        pending: {...now.pending}..remove(text),
        failed: now.failed,
      );
    } catch (_) {
      final now = state;
      state = PluginTranslationState(
        cache: now.cache,
        pending: {...now.pending}..remove(text),
        failed: {...now.failed, text},
      );
    }
  }
}

final pluginTranslationProvider = NotifierProvider<PluginTranslation, PluginTranslationState>(PluginTranslation.new);
