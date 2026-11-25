// A select field opens the app's choice sheet, never the platform dropdown
// overlay, and reports the value the user tapped.

import 'package:dsh_app/ui/common/app_select_field.dart';
import 'package:dsh_app/ui/common/choice_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/support/harness.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('a tap opens the sheet and picks a value', (tester) async {
    usePhoneView(tester);
    int? picked;
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: Center(
            child: AppSelectField<int>(
              label: 'Registry',
              selected: 0,
              choices: const [
                Choice(0, 'Mirror', subtitle: 'https://mirror.example.com'),
                Choice(1, 'Official', subtitle: 'https://npm.example.com'),
              ],
              onChanged: (value) => picked = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField), findsNothing);
    expect(find.text('Mirror'), findsOneWidget);

    await tester.tap(find.text('Mirror'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Official'), findsOneWidget);

    await tester.tap(find.text('Official'));
    await tester.pumpAndSettle();
    expect(picked, 1);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
