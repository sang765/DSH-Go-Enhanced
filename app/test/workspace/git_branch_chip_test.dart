import 'package:dsh_app/state/git_branch_state.dart';
import 'package:dsh_app/ui/workspace/git_branch_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../chat/support/harness.dart';

void main() {
  const scope = GitScope.session('s');

  testWidgets('the composer chip names the branch and opens the picker', (tester) async {
    await tester.pumpWidget(
      testApp(
        const Scaffold(body: Center(child: GitBranchChip(scope: scope))),
        overrides: [
          gitBranchProvider(
            scope,
          ).overrideWith((ref) async => const GitBranchInfo(isRepo: true, branch: 'main', branches: ['main'])),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer-branch')), findsOneWidget);
    expect(find.text('main'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('composer-branch')));
    await tester.pumpAndSettle();
    expect(find.text('Git 分支'), findsOneWidget);
  });

  testWidgets('a folder without a repository keeps the row as it was', (tester) async {
    await tester.pumpWidget(
      testApp(
        const Scaffold(body: Center(child: GitBranchChip(scope: scope))),
        overrides: [gitBranchProvider(scope).overrideWith((ref) async => GitBranchInfo.notRepo)],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer-branch')), findsNothing);
  });

  testWidgets('a detached HEAD still has something to tap', (tester) async {
    await tester.pumpWidget(
      testApp(
        const Scaffold(body: Center(child: GitBranchChip(scope: scope))),
        overrides: [
          gitBranchProvider(scope).overrideWith((ref) async => const GitBranchInfo(isRepo: true, branches: ['main'])),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('游离 HEAD'), findsOneWidget);
  });
}