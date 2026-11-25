import 'package:dsh_app/ui/common/app_select_field.dart';
import 'package:dsh_app/ui/plugins/add_plugin_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/support/harness.dart';

void main() {
  setUpAll(loadTestFonts);

  test('a spec becomes a short display name', () {
    expect(addPluginName('dsh-plugin-whale-pet'), 'dsh-plugin-whale-pet');
    expect(addPluginName('dsh-plugin-whale-pet@1.2.3'), 'dsh-plugin-whale-pet');
    expect(addPluginName('@scope/dsh-plugin@2.0.0'), '@scope/dsh-plugin');
    expect(addPluginName('https://github.com/owner/dsh-example.git'), 'dsh-example');
    expect(addPluginName('/home/u/plugins/dsh-local'), 'dsh-local');
  });

  test('custom registries are plain https origins', () {
    expect(isValidAddPluginRegistry('https://registry.npmjs.org'), isTrue);
    expect(isValidAddPluginRegistry('https://npm.example.com/'), isTrue);
    expect(isValidAddPluginRegistry('http://npm.example.com'), isFalse);
    expect(isValidAddPluginRegistry('https://npm.example.com/?x=1'), isFalse);
    expect(isValidAddPluginRegistry('https://npm.example.com/#x'), isFalse);
    expect(isValidAddPluginRegistry('not a url'), isFalse);
  });

  testWidgets('the registry uses a sheet-backed select, not a platform dropdown', (tester) async {
    usePhoneView(tester);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => FilledButton(
                onPressed: () => showAddPluginDialog(context: context, local: true),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(AppSelectField<int>), findsOneWidget);
    expect(find.byType(DropdownButtonFormField), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
