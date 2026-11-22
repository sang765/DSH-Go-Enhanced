// The market index carries a name, a summary and links but no README. The
// npm registry's package document does, for the same version; fetch it when
// a market detail sheet opens. Relative links in a README are relative to
// the repository, not to this app, so point them at GitHub's raw HEAD.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Largest README we bother to fetch and render (bytes).
const pluginReadmeMaxBytes = 512 * 1024;

Future<String?> _fetchReadme(http.Client client, Uri url) async {
  final request = http.Request('GET', url);
  final response = await client.send(request).timeout(const Duration(seconds: 8));
  if (response.statusCode != 200) {
    await response.stream.drain();
    throw StateError('readme HTTP ${response.statusCode}');
  }
  final declared = response.headers['content-length'];
  final declaredBytes = declared == null ? null : int.tryParse(declared);
  if (declaredBytes != null && declaredBytes > pluginReadmeMaxBytes) {
    await response.stream.drain();
    throw StateError('readme too large');
  }
  final bytes = await response.stream.fold<BytesBuilder>(
    BytesBuilder(),
    (builder, chunk) {
      if (builder.length + chunk.length > pluginReadmeMaxBytes) throw StateError('readme too large');
      builder.add(chunk);
      return builder;
    },
  );
  final data = jsonDecode(utf8.decode(bytes.takeBytes()));
  final readme = data is Map ? data['readme'] : null;
  return readme is String && readme.trim().isNotEmpty ? readme.trim() : null;
}

/// The README of [name] from npm, or null when it has none / nothing answers.
/// Keyed by package name: opening the same sheet again reuses the result.
final pluginReadmeProvider = FutureProvider.autoDispose.family<String?, String>((ref, name) async {
  final client = http.Client();
  ref.onDispose(client.close);
  final path = Uri.encodeComponent(name).replaceAll('%40', '@');
  for (final registry in ['https://registry.npmjs.org', 'https://registry.npmmirror.com']) {
    try {
      return await _fetchReadme(client, Uri.parse('$registry/$path'));
    } catch (_) {
      continue;
    }
  }
  return null;
});

/// `https://github.com/owner/repo` → `https://raw.githubusercontent.com/owner/repo/HEAD/`.
Uri? _githubRawBase(String? repositoryUrl) {
  final uri = Uri.tryParse(repositoryUrl ?? '');
  if (uri == null || uri.host.toLowerCase() != 'github.com') return null;
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length < 2) return null;
  final repo = segments[1].endsWith('.git') ? segments[1].substring(0, segments[1].length - 4) : segments[1];
  return Uri.https('raw.githubusercontent.com', '/${segments[0]}/$repo/HEAD/');
}

/// A few HTML tags GitHub READMEs use that the Markdown renderer would
/// otherwise show as literal text. Everything else (tables, task lists,
/// fenced code, `<details>`) is already handled by the renderer itself.
// A `)` in the src would close the Markdown image early and inject markup.
final _htmlImage = RegExp(r"""<img\s[^>]*?src\s*=\s*["']([^"'\s)]+)["'][^>]*>""", caseSensitive: false);
// A README is untrusted: an absolute remote image would be fetched silently
// (IP/tracking leak, uncapped download) and `data:` decodes on the UI thread.
// Keep relative images — resolveReadmeUrls points them at the repo's raw host —
// and turn the rest into links the reader taps deliberately.
final _absoluteImage = RegExp(r'!\[([^\]]*)\]\(((?:https?:|data:)[^)\s]+)\)', caseSensitive: false);
final _htmlBreak = RegExp(r'<br\s*/?>', caseSensitive: false);
final _htmlHeading = RegExp(r'<h([1-6])\b[^>]*>(.*?)</h\1>', caseSensitive: false, dotAll: true);
final _htmlWrapper = RegExp(r'</?(?:p|div|span|center|strong|b|em|i)\b[^>]*>', caseSensitive: false);

String normalizeReadme(String text) => text
    .replaceAllMapped(_htmlImage, (m) => '![](${m.group(1)})')
    .replaceAll(_htmlBreak, '\n')
    .replaceAllMapped(_htmlHeading, (m) => '${'#' * int.parse(m.group(1)!)} ${m.group(2)}')
    .replaceAll(_htmlWrapper, '')
    .replaceAllMapped(_absoluteImage, (m) => '[${m.group(1)}](${m.group(2)})');

final _mdTarget = RegExp(r'(!?\[[^\]]*\]\()([^)\s]+)([^)]*\))');

/// Points relative Markdown links and images at the plugin's repository so
/// screenshots and docs inside a README actually load.
String resolveReadmeUrls(String readme, {String? repositoryUrl, String? directory}) {
  final base = _githubRawBase(repositoryUrl);
  if (base == null) return readme;
  final prefix = directory == null || directory.isEmpty ? '' : '${directory.replaceAll(RegExp(r'^/|/$'), '')}/';
  return readme.replaceAllMapped(_mdTarget, (match) {
    final target = match.group(2)!;
    final lower = target.toLowerCase();
    if (lower.startsWith('http:') ||
        lower.startsWith('https:') ||
        lower.startsWith('data:') ||
        lower.startsWith('mailto:') ||
        target.startsWith('#') ||
        target.startsWith('//')) {
      return match.group(0)!;
    }
    final clean = target.startsWith('./')
        ? target.substring(2)
        : target.startsWith('/')
            ? target.substring(1)
            : target;
    return '${match.group(1)}$base$prefix$clean${match.group(3)}';
  });
}
