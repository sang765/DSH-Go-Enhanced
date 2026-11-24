import 'package:dsh_app/state/git_branch_state.dart';
import 'package:dsh_app/state/git_repository_state.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gitBranchFromHead', () {
    test('reads the branch a normal HEAD points at', () {
      expect(gitBranchFromHead('ref: refs/heads/main\n'), 'main');
      expect(gitBranchFromHead('ref: refs/heads/feature/git-branch\r\n'), 'feature/git-branch');
    });

    test('reports nothing for a detached HEAD or a foreign ref', () {
      expect(gitBranchFromHead('9f2c1b4e5a6d7c8b9a0e1f2a3b4c5d6e7f809123\n'), isNull);
      expect(gitBranchFromHead('ref: refs/tags/v1.0.0\n'), isNull);
      expect(gitBranchFromHead(''), isNull);
    });
  });

  group('parsePackedRefsHeads', () {
    test('keeps local branches and drops remote, peeled and comment lines', () {
      const packed = '''
# pack-refs with: peeled fully-peeled sorted
9f2c1b4e5a6d7c8b9a0e1f2a3b4c5d6e7f809123 refs/heads/main
1a2b3c4d5e6f708192a3b4c5d6e7f80912345678 refs/heads/develop
7f6e5d4c3b2a1908172635443322110099887766 refs/remotes/origin/main
^1122334455667788990011223344556677889900
''';
      expect(parsePackedRefsHeads(packed), ['main', 'develop']);
      expect(parsePackedRefsHeads(''), isEmpty);
    });
  });

  group('isValidGitRefName', () {
    test('accepts ordinary and nested branch names', () {
      for (final name in ['main', 'feature/git-branch', 'release-1.3.0', 'a_b.c']) {
        expect(isValidGitRefName(name), isTrue, reason: name);
      }
    });

    test('refuses names a shell or git could read as something else', () {
      for (final name in [
        '',
        '-D',
        'main; rm -rf /',
        "main'",
        'ma in',
        'a..b',
        'ends/',
        r'main$(id)',
      ]) {
        expect(isValidGitRefName(name), isFalse, reason: name);
      }
    });
  });

  test('a scope compares by kind, id and folder', () {
    expect(const GitScope.session('s1'), const GitScope.session('s1'));
    expect(const GitScope.session('s1'), isNot(const GitScope.workspace('s1')));
    expect(
      const GitScope.workspace('w1', workspacePath: '/w'),
      isNot(const GitScope.workspace('w1', workspacePath: '/other')),
    );
  });

  group('linked worktrees', () {
    test('reads the git directory a .git file names', () {
      expect(gitDirFromFile('gitdir: ../main/.git/worktrees/fix-login\n'), '../main/.git/worktrees/fix-login');
      expect(gitDirFromFile('gitdir: /srv/main/.git/worktrees/fix\n'), '/srv/main/.git/worktrees/fix');
      expect(gitDirFromFile('9f2c1b4e5a6d7c8b9a0e1f2a3b4c5d6e7f809123\n'), isNull);
      expect(gitDirFromFile('gitdir: \n'), isNull);
    });

    test('only reaches a git directory that stays inside the folder', () {
      expect(reachableGitDir('.git/worktrees/fix'), '.git/worktrees/fix');
      expect(reachableGitDir('../main/.git/worktrees/fix'), isNull);
      expect(reachableGitDir('/srv/main/.git/worktrees/fix'), isNull);
      expect(reachableGitDir('C:/repo/.git/worktrees/fix'), isNull);
    });
  });

  group('remote branches on disk', () {
    test('lists packed remote refs without the symbolic HEAD', () {
      const packed = '''
# pack-refs with: peeled fully-peeled sorted
9f2c1b4e5a6d7c8b9a0e1f2a3b4c5d6e7f809123 refs/remotes/origin/main
1a2b3c4d5e6f708192a3b4c5d6e7f80912345678 refs/remotes/origin/HEAD
''';
      expect(parsePackedRefsRemotes(packed), ['origin/main', 'origin/HEAD']);
      expect(parsePackedRefsRemotes(''), isEmpty);
    });
  });

  test('a repository with uncommitted changes says so, an unread one does not', () {
    expect(const GitBranchInfo(isRepo: true, branch: 'main', changedFiles: 2).dirty, isTrue);
    expect(const GitBranchInfo(isRepo: true, branch: 'main', changedFiles: 0).dirty, isFalse);
    expect(const GitBranchInfo(isRepo: true, branch: 'main').dirty, isFalse);
  });

  test('the live watch follows the checked-out branch and both ref stores', () {
    // Dropping any of these leaves the chip stale after a switch, a new
    // branch or a fetch.
    expect(gitWatchTargets, contains('.git/HEAD'));
    expect(gitWatchTargets, contains('.git/refs/heads'));
    expect(gitWatchTargets, contains('.git/packed-refs'));
    expect(gitWatchNeedsReread(const DshWorkspaceWatchChange(absolutePath: '/w/.git/HEAD', version: 'v2')), isTrue);
    expect(gitWatchNeedsReread(const DshWorkspaceWatchReady()), isFalse);
  });

  test('a worktree watches the only path inside the folder it has', () {
    // Its git directory lives outside, so following the ref files there would
    // watch paths that do not exist.
    expect(gitWatchTargetsFor(const GitBranchInfo(isRepo: true, worktree: true)), ['.git']);
    expect(gitWatchTargetsFor(const GitBranchInfo(isRepo: true)), gitWatchTargets);
  });
}
