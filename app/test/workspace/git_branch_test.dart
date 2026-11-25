import 'dart:async';

import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/state/git_branch_state.dart';
import 'package:dsh_app/state/git_repository_state.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Host whose workspace is an in-memory tree, with no terminals: the file
/// tier is the only one, so every re-read lists the tree again.
class _TreeClient extends DshClient {
  _TreeClient() : super(DshConnection(Uri.parse('http://127.0.0.1:9')));

  final files = <String, String>{};
  final children = <String, List<DshWorkspaceEntry>>{};
  final watchFrames = StreamController<DshWorkspaceWatchFrame>.broadcast();
  int lists = 0;

  @override
  bool get supportsTerminals => false;

  @override
  Future<DshWorkspaceListing> listWorkspace(String sessionId, String path) async {
    lists++;
    return DshWorkspaceListing(path: path, entries: children[path] ?? const <DshWorkspaceEntry>[]);
  }

  @override
  Future<DshWorkspaceText> readWorkspaceText(
    String sessionId,
    String path, {
    int offset = 1,
    int limit = 500,
  }) async => DshWorkspaceText(text: files[path] ?? '', lines: 0, eof: true, offset: offset);

  @override
  Stream<DshWorkspaceWatchFrame> watchWorkspace(String sessionId, String path) => watchFrames.stream;
}

_TreeClient _repoWithBranch(String branch) {
  final client = _TreeClient();
  const dir = DshWorkspaceEntry(name: '.git', type: DshWorkspaceEntryType.directory);
  client.children[''] = const [dir];
  client.files['.git/HEAD'] = 'ref: refs/heads/$branch\n';
  return client;
}

const _nestedDir = DshWorkspaceEntry(name: 'feature', type: DshWorkspaceEntryType.directory);
const _teamDir = DshWorkspaceEntry(name: 'team', type: DshWorkspaceEntryType.directory);
const _topicDir = DshWorkspaceEntry(name: 'topic', type: DshWorkspaceEntryType.directory);
const _subDir = DshWorkspaceEntry(name: 'sub', type: DshWorkspaceEntryType.directory);
const _fixRef = DshWorkspaceEntry(name: 'fix', type: DshWorkspaceEntryType.file);

/// The active connection, switchable mid-test to model a reconnect that
/// publishes a new client for the same Host.
class _SwitchConnection extends Notifier<AsyncValue<HostConnection?>> {
  static late HostConnection initial;

  @override
  AsyncValue<HostConnection?> build() => AsyncData(initial);

  void use(HostConnection connection) => state = AsyncData(connection);
}

final _switchConnection = NotifierProvider<_SwitchConnection, AsyncValue<HostConnection?>>(_SwitchConnection.new);

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

  test('the live watch follows the checked-out branch, both ref stores and edits', () {
    // Dropping any of these leaves the chip stale after a switch, a new
    // branch, a fetch or an unstaged edit.
    expect(gitWatchTargets, contains(''));
    expect(gitWatchTargets, contains('.git/HEAD'));
    expect(gitWatchTargets, contains('.git/refs/heads'));
    expect(gitWatchTargets, contains('.git/packed-refs'));
    expect(gitWatchTargets, contains('.git/index'));
    expect(gitWatchNeedsReread(const DshWorkspaceWatchChange(absolutePath: '/w/.git/HEAD', version: 'v2')), isTrue);
    expect(gitWatchNeedsReread(const DshWorkspaceWatchReady()), isFalse);
  });

  test('a worktree follows its .git file and the root for unstaged edits', () {
    // Its git directory lives outside, so following the ref files there would
    // watch paths that do not exist.
    expect(gitWatchTargetsFor(const GitBranchInfo(isRepo: true, worktree: true)), ['', '.git']);
    expect(gitWatchTargetsFor(const GitBranchInfo(isRepo: true)), gitWatchTargets);
  });

  test('loose refs several directory levels deep are still branches', () async {
    final client = _repoWithBranch('main');
    client.children['.git/refs/heads'] = const [_nestedDir];
    client.children['.git/refs/heads/feature'] = const [_teamDir];
    client.children['.git/refs/heads/feature/team'] = const [_topicDir];
    client.children['.git/refs/heads/feature/team/topic'] = const [_subDir];
    client.children['.git/refs/heads/feature/team/topic/sub'] = const [_fixRef];

    final info = await readGitBranch(client, const GitScope.workspace('w'));
    expect(info.isRepo, isTrue);
    expect(info.branches, ['feature/team/topic/sub/fix', 'main']);
  });

  test('a client-replacing reconnect is a new git connection key, a relabel is not', () {
    final first = _TreeClient();
    final second = _TreeClient();
    final original = gitConnectionKey(HostConnection(client: first, isLocal: false, hostId: 'same'));
    expect(
      original,
      gitConnectionKey(HostConnection(client: first, label: 'renamed', isLocal: false, hostId: 'same')),
    );
    expect(original, isNot(gitConnectionKey(HostConnection(client: second, isLocal: false, hostId: 'same'))));
    expect(gitConnectionKey(null), isNull);
  });

  test('an unstaged edit in the workspace root re-reads the dirty count', () async {
    final client = _repoWithBranch('main');
    _SwitchConnection.initial = HostConnection(client: client, isLocal: true);
    final container = ProviderContainer(
      overrides: [activeConnectionProvider.overrideWith((ref) => ref.watch(_switchConnection))],
    );
    addTearDown(container.dispose);
    addTearDown(client.watchFrames.close);
    const scope = GitScope.workspace('w');
    final subscription = container.listen(gitBranchProvider(scope), (_, __) {});
    addTearDown(subscription.close);

    expect((await container.read(gitBranchProvider(scope).future)).branch, 'main');
    final before = client.lists;
    // An unstaged file edit changes the root, not `.git/index`.
    client.watchFrames.add(const DshWorkspaceWatchChange(absolutePath: '/w/notes.txt', version: 'v2'));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(client.lists, greaterThan(before));
  });

  test('a new client on the same Host re-reads the branch; a relabel does not', () async {
    final first = _repoWithBranch('main');
    final second = _repoWithBranch('develop');
    _SwitchConnection.initial = HostConnection(client: first, isLocal: false, hostId: 'same');
    final container = ProviderContainer(
      overrides: [activeConnectionProvider.overrideWith((ref) => ref.watch(_switchConnection))],
    );
    addTearDown(container.dispose);
    const scope = GitScope.workspace('w');
    // Keep the autoDispose provider alive across the reconnect.
    final subscription = container.listen(gitBranchProvider(scope), (_, __) {});
    addTearDown(subscription.close);

    expect((await container.read(gitBranchProvider(scope).future)).branch, 'main');
    final afterFirst = first.lists;

    container.read(_switchConnection.notifier).use(
          HostConnection(client: first, label: 'renamed', isLocal: false, hostId: 'same'),
        );
    expect((await container.read(gitBranchProvider(scope).future)).branch, 'main');
    expect(first.lists, afterFirst, reason: 'a label change keeps the same client');

    container.read(_switchConnection.notifier).use(
          HostConnection(client: second, isLocal: false, hostId: 'same'),
        );
    expect((await container.read(gitBranchProvider(scope).future)).branch, 'develop');
    expect(second.lists, greaterThan(0));
  });
}
