// The installed list and its detail sheet fall back to the plugin directory's
// icon when the bundle itself has no image metadata (the web UI already does).

import 'dart:convert';

import 'package:dsh_app/ui/plugins/installed_tab.dart';
import 'package:dsh_app/ui/plugins/plugin_widgets.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/support/harness.dart';
import 'support/fake_plugin_host.dart';

const _catalogIcon = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8AAAwAB/AF+gAAAAABJRU5ErkJggg==';
const _bundleIcon = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M/wHwAE/wL+AZWUAAAAAElFTkSuQmCC';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('a bundle without image metadata uses the directory icon', (tester) async {
    final index = <String, Object?>{
      ...sampleIndex,
      'plugins': [
        {
          'name': 'icon-plugin',
          'title': 'Icon plugin',
          'description': 'Has a directory icon',
          'icon': _catalogIcon,
          'versions': [
            {'version': '1.0.0', 'publishTimestamp': 1, 'source': {'type': 'npm'}},
          ],
        },
      ],
    };
    final carrier = FakePluginCarrier();
    carrier.handlers['pluginManager/listBundles'] = (_) => sampleBundles;
    final client = DshClient.withCarrier(carrier);
    addTearDown(client.close);
    usePhoneView(tester);
    await tester.pumpWidget(
      testApp(
        Scaffold(body: BundleTile(bundle: PluginBundle.fromJson(bundleJson('icon-plugin')), readOnly: true, displaySnapshot: true)),
        overrides: pluginOverrides(fakeHost(client), index: index),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<PluginAvatar>(find.byType(PluginAvatar)).icon, _catalogIcon);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a bundle icon wins over the directory icon', (tester) async {
    final json = bundleJson('icon-plugin');
    json['meta'] = {'icon': _bundleIcon};
    final index = <String, Object?>{
      ...sampleIndex,
      'plugins': [
        {
          'name': 'icon-plugin',
          'title': 'Icon plugin',
          'description': 'Has a directory icon',
          'icon': _catalogIcon,
          'versions': [
            {'version': '1.0.0', 'publishTimestamp': 1, 'source': {'type': 'npm'}},
          ],
        },
      ],
    };
    final carrier = FakePluginCarrier();
    carrier.handlers['pluginManager/listBundles'] = (_) => sampleBundles;
    final client = DshClient.withCarrier(carrier);
    addTearDown(client.close);
    usePhoneView(tester);
    await tester.pumpWidget(
      testApp(
        Scaffold(body: BundleTile(bundle: PluginBundle.fromJson(json), readOnly: true, displaySnapshot: true)),
        overrides: pluginOverrides(fakeHost(client), index: index),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<PluginAvatar>(find.byType(PluginAvatar)).icon, _bundleIcon);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a bundle SVG icon renders as an SVG, not a letter', (tester) async {
    const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><rect width="1" height="1"/></svg>';
    final dataUrl = 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';
    final json = bundleJson('svg-plugin');
    json['meta'] = {'icon': dataUrl};
    final carrier = FakePluginCarrier();
    carrier.handlers['pluginManager/listBundles'] = (_) => sampleBundles;
    final client = DshClient.withCarrier(carrier);
    addTearDown(client.close);
    usePhoneView(tester);
    await tester.pumpWidget(
      testApp(
        Scaffold(body: BundleTile(bundle: PluginBundle.fromJson(json), readOnly: true, displaySnapshot: true)),
        overrides: pluginOverrides(fakeHost(client)),
      ),
    );
    await tester.pump();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.widget<PluginAvatar>(find.byType(PluginAvatar)).icon, dataUrl);
    expect(tester.takeException(), isNull);
  });
}
