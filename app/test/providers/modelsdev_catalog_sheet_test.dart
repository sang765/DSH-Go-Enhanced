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

/// Pumps until the catalogue leaves loading; reports the observed state so a
/// failure names what the notifier actually did.
Future<String> _untilLoaded(WidgetTester tester) async {
  var observed = 'never-read';
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    final container = ProviderScope.containerOf(tester.element(find.text('open')));
    final state = container.read(modelsDevCatalogProvider);
    observed = state.map(
      data: (_) => 'data(${state.value!.providers.length})',
      error: (e) => 'error(${e.error})',
      loading: (_) => 'loading',
    );
    if (observed != 'loading') break;
  }
  // ignore: avoid_print
  print('catalog state after pumps: $observed');
  return observed;
}

Future<void> _pumpCatalog(WidgetTester tester, {UpdateHttp? http}) async {
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
              onPressed: () => showProviderCatalogSheet(context),
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
    expect(find.text('api.example.com'), findsOneWidget);
    expect(find.text('1 model'), findsOneWidget);
  });

  testWidgets('search filters by name', (tester) async {
    await _pumpCatalog(tester, http: _FakeHttp(body: _catalogJson));
    await tester.enterText(find.byType(TextField).first, 'example');
    await settle(tester);
    expect(find.text('Example Cloud'), findsOneWidget);
    expect(find.text('Anthro Like'), findsNothing);
    expect(find.text('没有匹配的渠道'), findsNothing);
  });

  testWidgets('a fetch failure offers a retry that loads the list', (tester) async {
    final http = _FakeHttp(error: const HttpException('offline'));
    await _pumpCatalog(tester, http: http);
    expect(find.text('无法从 models.dev 加载渠道列表'), findsOneWidget);
    // Retry now succeeds.
    http.error = null;
    await tester.tap(find.text('重试'));
    final observed = await _untilLoaded(tester);
    expect(observed, startsWith('data(2)'), reason: 'the retry reloaded the catalogue');
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
    await tester.runAsync(loadGoldenFonts);
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(390 * 2, 1400 * 2);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      goldenApp(
        brightness: Brightness.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () async {
                  picked = await showProviderCatalogSheet(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
        overrides: [modelsDevHttpProvider.overrideWithValue(_FakeHttp(body: _catalogJson))],
      ),
    );
    await tester.tap(find.text('open'));
    await _untilLoaded(tester);
    await tester.tap(find.text('Example Cloud'));
    await settle(tester);
    expect(picked?.id, 'example');
    expect(picked?.apiUrl, 'https://api.example.com/v1');
    expect(protocolOf(picked!), ProviderApi.openaiCompletions);
  });
}
