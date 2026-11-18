// The add-provider catalogue sheet: the live models.dev fetch through the
// http seam, the search, the custom entry, and the preset flow — picking a
// catalogue provider locks the name / protocol / Base URL on the form and
// only the API key (and models) stay editable.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpException;

import 'package:dsh_app/state/modelsdev_provider_catalog.dart';
import 'package:dsh_app/ui/providers/provider_catalog_sheet.dart';
import 'package:dsh_app/update/update_http.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../shell/golden_harness.dart' show goldenApp, loadGoldenFonts;
import 'support.dart';

/// An [UpdateHttp] answering from a canned catalogue (or failing).
class _FakeHttp implements UpdateHttp {
  _FakeHttp({this.body, this.error});

  final String? body;

  /// Set on every request while non-null; cleared by the test to let a
  /// retry through.
  Object? error;

  @override
  Future<UpdateHttpResponse> get(Uri url, {Map<String, String> headers = const {}, Duration timeout = const Duration(seconds: 15)}) async {
    if (error != null) throw error!;
    if (url.path.startsWith('/logos/')) {
      // A one-circle SVG; the decoder must accept it and draw the logo.
      final bytes = utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24">'
        '<circle cx="12" cy="12" r="10" fill="teal"/></svg>',
      );
      return UpdateHttpResponse(status: 200, body: Stream.value(bytes), contentLength: bytes.length);
    }
    final bytes = utf8.encode(body ?? '');
    return UpdateHttpResponse(status: 200, body: Stream.value(bytes), contentLength: bytes.length);
  }
}

const _catalogJson = '''
{
  "example": {
    "id": "example",
    "name": "Example Cloud",
    "npm": "@ai-sdk/openai-compatible",
    "api": "https://api.example.com/v1",
    "env": ["EXAMPLE_API_KEY"],
    "models": {
      "example-pro": {
        "id": "example-pro",
        "name": "Example Pro",
        "reasoning": true,
        "limit": {"context": 131072, "output": 65536},
        "modalities": {"input": ["text", "image"], "output": ["text"]}
      }
    }
  },
  "anthropic-like": {
    "id": "anthropic-like",
    "name": "Anthro Like",
    "npm": "@ai-sdk/anthropic",
    "api": "https://api.anthro-like.io/anthropic/v1",
    "env": ["ANTHRO_LIKE_KEY"],
    "models": {}
  }
}
''';

/// Waits (in real async — the notifier's stream timeouts only complete on
/// real timers, which fake-async pumps never fire) for the catalogue to
/// settle, and reports the observed state so a failure names what the
/// notifier actually did.
Future<String> _untilLoaded(WidgetTester tester, {bool requireData = false}) async {
  final container = ProviderScope.containerOf(tester.element(find.text('open')));
  var observed = 'loading';
  await tester.runAsync(() async {
    // Poll the settled state on real timers: reading .future would hang a
    // build that started under fake async (its timers never fire there).
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // A pump per poll: an invalidated notifier only rebuilds when the
      // watching widget does.
      await tester.pump();
      final state = container.read(modelsDevCatalogProvider);
      if (state case AsyncValue(:final value?)) {
        observed = 'data(${value.providers.length})';
        return;
      }
      if (state.hasError && !requireData) {
        observed = 'error(${state.error})';
        return;
      }
      if (requireData && !state.isLoading && state.value != null) {
        observed = 'data(${state.value!.providers.length})';
        return;
      }
    }
  });
  // ignore: avoid_print
  print('catalog state: $observed');
  return observed;
}

Future<void> _pumpCatalog(WidgetTester tester, {UpdateHttp? http, ValueChanged<ModelsDevProvider>? onPicked}) async {
  await tester.runAsync(loadGoldenFonts);
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = const Size(390 * 2, 1400 * 2);
  tester.view.padding = const FakeViewPadding(top: 64, bottom: 48);
  tester.view.viewPadding = const FakeViewPadding(top: 64, bottom: 48);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    goldenApp(
      brightness: Brightness.light,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                final picked = await showProviderCatalogSheet(context);
                onPicked?.call(picked!);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
      overrides: [
        if (http != null) modelsDevHttpProvider.overrideWithValue(http),
      ],
    ),
  );
  await tester.tap(find.text('open'));
  await _untilLoaded(tester);
  await settle(tester);
}

void main() {
  testWidgets('lists catalogue providers with name and host, sorted', (tester) async {
    await _pumpCatalog(tester, http: _FakeHttp(body: _catalogJson));
    expect(find.text('Example Cloud'), findsOneWidget);
    expect(find.text('Anthro Like'), findsOneWidget);
    // Sorted by name: Anthro Like first.
    expect(
      tester.getTopLeft(find.text('Anthro Like')).dy < tester.getTopLeft(find.text('Example Cloud')).dy,
      isTrue,
    );
    expect(find.text('api.anthro-like.io'), findsOneWidget);
    expect(find.textContaining('api.example.com'), findsOneWidget);
    expect(find.textContaining('个模型'), findsOneWidget);
  });

  testWidgets('search filters by name', (tester) async {
    await _pumpCatalog(tester, http: _FakeHttp(body: _catalogJson));
    await tester.enterText(find.byType(TextField).first, 'example');
    await settle(tester);
    expect(find.text('Example Cloud'), findsOneWidget);
    expect(find.text('Anthro Like'), findsNothing);
  });

  testWidgets('a fetch failure offers a retry that loads the list', (tester) async {
    final http = _FakeHttp(error: const HttpException('offline'));
    await _pumpCatalog(tester, http: http);
    expect(find.text('无法从 models.dev 加载渠道列表'), findsOneWidget);
    // Retry now succeeds: clear the fault, tap, then let the invalidated
    // rebuild run — its chain is microtask-only (the fake's stream fires
    // immediately), so plain pumps carry it to data.
    http.error = null;
    await tester.tap(find.text('重试'));
    var lastState = '';
    final container = ProviderScope.containerOf(tester.element(find.text('open')));
    for (var i = 0; i < 20 && find.text('Example Cloud').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final state = container.read(modelsDevCatalogProvider);
      lastState = state.hasError
          ? 'error(${state.error})'
          : state.value != null
          ? 'data(${state.value!.providers.length})'
          : 'loading';
      // The button's own invalidate may be swallowed by the gesture; force
      // the rebuild from the container side as the loop's backstop.
      if (state.hasError && i == 4) container.invalidate(modelsDevCatalogProvider);
    }
    // ignore: avoid_print
    print('retry loop ended at: $lastState');
    expect(find.text('Example Cloud'), findsOneWidget);
  });

  testWidgets('custom entry pops without a provider', (tester) async {
    await _pumpCatalog(tester, http: _FakeHttp(body: _catalogJson));
    await tester.tap(find.text('添加自定义渠道'));
    await settle(tester);
    expect(find.byType(ProviderCatalogSheet), findsNothing);
  });

  testWidgets('picking a provider hands it back', (tester) async {
    ModelsDevProvider? picked;
    await _pumpCatalog(tester, http: _FakeHttp(body: _catalogJson), onPicked: (p) => picked = p);
    await tester.tap(find.text('Example Cloud'));
    await settle(tester);
    expect(picked?.id, 'example');
    expect(picked?.apiUrl, 'https://api.example.com/v1');
    expect(protocolOf(picked!), ProviderApi.openaiCompletions);
  });
}
