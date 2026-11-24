import 'package:dsh_app/state/git_branch_state.dart';
import 'package:dsh_app/ui/common/list_page_row.dart';
import 'package:dsh_app/ui/common/row_marks.dart';
import 'package:dsh_app/ui/workspace/git_branch_sheet.dart';
import 'package:dsh_app/ui/workspace/git_remote_branches_page.dart';
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
    expect(find.byKey(const ValueKey('composer-branch-dirty')), findsNothing);

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

  testWidgets('uncommitted changes mark the chip with a dot', (tester) async {
    await tester.pumpWidget(
      testApp(
        const Scaffold(body: Center(child: GitBranchChip(scope: scope))),
        overrides: [
          gitBranchProvider(scope).overrideWith(
            (ref) async => const GitBranchInfo(isRepo: true, branch: 'main', branches: ['main'], changedFiles: 3),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('composer-branch-dirty')), findsOneWidget);
  });

  test('a remote branch loses only its first path segment', () {
    expect(remoteBranchShortName('origin/develop'), 'develop');
    expect(remoteBranchShortName('upstream/feature/x'), 'feature/x');
    expect(remoteBranchShortName('develop'), 'develop');
  });

  testWidgets('the remote branches page lists remotes and the local branch each makes', (tester) async {
    await tester.pumpWidget(
      testApp(
        const Scaffold(body: Center(child: GitBranchChip(scope: scope))),
        overrides: [
          gitBranchProvider(scope).overrideWith(
            (ref) async => const GitBranchInfo(
              isRepo: true,
              branch: 'develop',
              branches: ['develop', 'main'],
              remotes: ['origin/develop', 'upstream/feature/x'],
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('composer-branch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('远程分支'));
    await tester.pumpAndSettle();

    expect(find.byType(GitRemoteBranchesPage), findsOneWidget);
    expect(find.text('origin/develop'), findsOneWidget);
    expect(find.text('upstream/feature/x'), findsOneWidget);
    expect(find.text('develop'), findsOneWidget);
    expect(find.text('feature/x'), findsOneWidget);

    RowCheck checkOn(String remote) => tester.widget<RowCheck>(
      find.descendant(
        of: find.ancestor(of: find.text(remote), matching: find.byType(ListPageRow)),
        matching: find.byType(RowCheck),
      ),
    );
    expect(checkOn('origin/develop').visible, isTrue);
    expect(checkOn('upstream/feature/x').visible, isFalse);
  });

  testWidgets('the new-branch row asks for a name and refuses an unusable one', (tester) async {
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
    await tester.tap(find.byKey(const ValueKey('composer-branch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建分支'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('分支名'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bad name');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('分支名不可用'), findsOneWidget);
  });
}