// The installed-plugin list and its detail sheet pick a plugin's name and
// description in the app's language when the plugin ships both.

import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/ui/plugins/installed_tab.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/support/harness.dart';
import 'support/fake_plugin_host.dart';

void main() {
  setUpAll(loadTestFonts);
  tearDown(() => AppLocale.use(AppLocale.zhCN));

  for (final locale in [AppLocale.zhCN, AppLocale.en]) {
    final english = locale.languageCode == 'en';

    testWidgets('installed tile uses $locale for a bilingual plugin', (tester) async {
      AppLocale.use(locale);
      final bundle = PluginBundle.fromJson(
        bundleJson(
          'bilingual-plugin',
          title: {'zh': '双语插件', 'en': 'Bilingual plugin'},
          description: {'zh': '这是中文说明', 'en': 'This is the English description'},
        ),
      );
      final carrier = FakePluginCarrier();
      carrier.handlers['pluginManager/listBundles'] = (_) => sampleBundles;
      final client = DshClient.withCarrier(carrier);
      addTearDown(client.close);
      usePhoneView(tester);
      await tester.pumpWidget(
        testApp(
          Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: locale,
              child: Scaffold(body: BundleTile(bundle: bundle, readOnly: true, displaySnapshot: true)),
            ),
          ),
          overrides: pluginOverrides(fakeHost(client)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(english ? 'Bilingual plugin' : '双语插件'), findsOneWidget);
      // The subtitle also carries the version, so match inside that Text.
      expect(find.textContaining(english ? 'This is the English description' : '这是中文说明'), findsOneWidget);
      expect(find.text(english ? '双语插件' : 'Bilingual plugin'), findsNothing);
      expect(find.textContaining(english ? '这是中文说明' : 'This is the English description'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
