import 'package:dsh_app/state/balance_state.dart';
import 'package:dsh_app/state/chat_state.dart';
import 'package:dsh_app/state/usage_state.dart';
import 'package:dsh_app/ui/chat/usage_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/haptics.dart';
import 'support/harness.dart';

class _FakeBalanceController extends BalanceController {
  @override
  BalanceState build() => const BalanceState(status: BalanceStatus.noKey);

  @override
  Future<void> refresh() async {}
}

void main() {
  for (final sheet in [true, false]) {
    testWidgets('context usage keeps values and labels aligned (sheet: $sheet)', (tester) async {
      Future<void> show(SessionUsage usage) async {
        await tester.pumpWidget(
          testApp(
            Scaffold(
              body: SingleChildScrollView(
                child: SessionUsageSections(usage: usage, sheet: sheet),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(
        const SessionUsage(pressureTokens: 840, projectedTokens: 400, contextWindow: 1000, messageTokens: 300),
      );
      expect(find.text('预计下次请求'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text('400 / 1K'), findsOneWidget);
      expect(find.text('累计输入'), findsOneWidget);

      await show(const SessionUsage(pressureTokens: 840, contextWindow: 1000));
      expect(find.text('上次请求'), findsOneWidget);
      expect(find.text('84%'), findsOneWidget);
      expect(find.text('840 / 1K'), findsOneWidget);

      await show(const SessionUsage(contextWindow: 1000));
      expect(find.text('0%'), findsNothing);
      expect(find.text('0 / 1K'), findsNothing);
    });
  }

  testWidgets('Usage sheet offers compaction only when context is in use', (tester) async {
    final chat = FakeChatController('s', const ChatState(loading: false));
    Future<void> show(SessionUsage usage, {required bool sheet}) async {
      await tester.pumpWidget(
        testApp(
          Scaffold(
            body: sheet
                ? UsageSheet(sessionId: 's')
                : SingleChildScrollView(child: SessionUsageSections(usage: usage)),
          ),
          overrides: [
            sessionUsageProvider.overrideWith2((id) => FakeUsage(id, usage)),
            balanceProvider.overrideWith(_FakeBalanceController.new),
            chatProvider('s').overrideWith(() => chat),
          ],
        ),
      );
      await tester.pumpAndSettle();
    }

    await show(const SessionUsage(pressureTokens: 840, projectedTokens: 400, contextWindow: 1000), sheet: true);
    expect(find.text('压缩上下文'), findsOneWidget);
    final felt = recordHaptics(tester);
    await tester.tap(find.text('压缩上下文'));
    await tester.pumpAndSettle();
    expect(chat.commandLines, ['/compact']);
    expect(felt, ['HapticFeedbackType.selectionClick']);

    // A fresh session has no context projection: no button to tap.
    await show(const SessionUsage(contextWindow: 1000), sheet: true);
    expect(find.text('压缩上下文'), findsNothing);

    // The action belongs to the Usage sheet, not the chat detail section.
    await show(const SessionUsage(pressureTokens: 840, contextWindow: 1000), sheet: false);
    expect(find.text('压缩上下文'), findsNothing);
  });
}
