import 'dart:async';

import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/state/git_branch_state.dart';
import 'package:dsh_app/state/git_repository_state.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A carrier whose workspace is an in-memory tree. `DshClient`'s workspace and
/// terminal APIs are extensions, so a fake carrier — not a client subclass — is
/// the seam that answers them.
class _TreeCarrier extends DshCarrier {
  _TreeCarrier({this.terminals = false, Map<String, String>? files, Map<String, List<DshWorkspaceEntry>>? children})
    : files = files ?? <String, String>{},
      children = children ?? <String, List<DshWorkspaceEntry>>{};

  /// Terminal capability is only needed by the provider tests, where the
  /// probe itself is replaced; the file-tier tests answer no endpoint at all.
  final bool terminals;
  final Map<String, String> files;
  final Map<String, List<DshWorkspaceEntry>> children;
  int lists = 0;

  @override
  String get kind => 'fake';

  @override
  DshTracer? get tracer => null;

  @override
  bool get supportsUplink => false;

  @override
  bool allowsEndpoint(String endpoint) => terminals && endpoint.startsWith('terminal/');

  @override
  Future<RpcResult> call(String endpoint, Map<String, Object?> args, {Duration? timeout}) async {
    switch (endpoint) {
      case 'workspaceFiles/list':
        lists++;
        final raw = args['path'] as String? ?? '';
        final path = raw == '.' ? '' : raw;
        return RpcOk({
          'path': path,
          'entries': [
            for (final entry in children[path] ?? const <DshWorkspaceEntry>[])
              {'name': entry.name, 'type': entry.type.name},
          ],
        });
      case 'workspaceFiles/read':
        final path = args['path'] as String? ?? '';
        final text = files[path];
        if (text == null) throw StateError('no file $path');
        return RpcOk({'text': text, 'lines': 0, 'eof': true, 'offset': 1, 'absolutePath': path});
    }
    return RpcOk(null);
  }

  @override
  Future<DshMuxLink> openLink(MuxOptions options) async => _QuietLink();

  @override
  Future<void> close() async {}
}

/// A link that only answers the mux's ready handshake, so the client has a
/// generation before the provider reads it. No workspace watch frames.
class _QuietLink implements DshMuxLink {
  DshMuxFrameHandler? _onFrame;

  @override
  void start({required DshMuxFrameHandler onFrame, required DshMuxLossHandler onLost}) {
    _onFrame = onFrame;
  }

  @override
  void open(String streamId, String endpoint, Map<String, Object?> payload) {
    if (endpoint != r'$events') return;
    scheduleMicrotask(
      () => _onFrame?.call({
        'type': 'item',
        'streamId': streamId,
        'value': {'type': 'ready', 'clientId': 'test', 'host': {'home': '/root'}},
      }),
    );
  }

  @override
  void sendItem(String streamId, Object? value) {}

  @override
  void endUplink(String streamId) {}

  @override
  void cancel(String streamId) {}

  @override
  Future<void> close(int code, String reason) async {}
}

Future<DshClient> _client(_TreeCarrier carrier) async {
  final client = DshClient.withCarrier(carrier, muxOptions: const MuxOptions(retryCaps: [Duration(milliseconds: 1)]));
  addTearDown(client.close);
  // The provider skips the terminal tier while the mux has no generation.
  await client.mux.ready(timeout: const Duration(seconds: 5));
  return client;
}

_TreeCarrier _repoCarrier(String branch) => _TreeCarrier(
  files: {'.git/HEAD': 'ref: refs/heads/$branch\n'},
  children: {'': const [DshWorkspaceEntry(name: '.git', type: DshWorkspaceEntryType.directory)]},
);

const _nestedDir = DshWorkspaceEntry(name: 'feature', type: DshWorkspaceEntryType.directory);
const _teamDir = DshWorkspaceEntry(name: 'team', type: DshWorkspaceEntryType.directory);
const _topicDir = DshWorkspaceEntry(name: 'topic', type: DshWorkspaceEntryType.directory);
const _subDir = DshWorkspaceEntry(name: 'sub', type: DshWorkspaceEntryType.directory);
const _fixRef = DshWorkspaceEntry(name: 'fix', type: DshWorkspaceEntryType.file);

/// The probe tier replaced in provider tests: no terminal, just the branch
/// each client would report.
class _ProbeService implements GitHostService {
  _ProbeService(this.branches);

  final Map<DshClient, String> branches;
  int calls = 0;

  @override
  Future<GitProbeState?> probe({
    required DshClient client,
    required String sessionId,
    required bool Function() stillCurrent,
  }) async {
    calls++;
    final branch = branches[client];
    if (branch == null) return null;
    return GitProbeState(
      branch: branch,
      changedFiles: 0,
      branches: [branch],
      remotes: const [],
      worktree: false,
    );
  }

  @override
  Future<GitCloneOutcome> clone({
    required DshClient client,
    required GitRepoSpec spec,
    required String parentPath,
    required bool Function() stillCurrent,
    void Function(String)? onProgress,
  }) => throw UnimplementedError();

  @override
  Future<GitCheckoutOutcome> checkout({
    required DshClient client,
    required String cwd,
    required String branch,
    required bool Function() stillCurrent,
    bool create = false,
  }) => throw UnimplementedError();
}

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
    final carrier = _repoCarrier('main');
    carrier.children['.git/refs/heads'] = const [_nestedDir];
    carrier.children['.git/refs/heads/feature'] = const [_teamDir];
    carrier.children['.git/refs/heads/feature/team'] = const [_topicDir];
    carrier.children['.git/refs/heads/feature/team/topic'] = const [_subDir];
    carrier.children['.git/refs/heads/feature/team/topic/sub'] = const [_fixRef];

    final info = await readGitBranch(await _client(carrier), const GitScope.workspace('w'));
    expect(info.isRepo, isTrue);
    expect(info.branches, ['feature/team/topic/sub/fix', 'main']);
  });

  test('a client-replacing reconnect is a new git connection key, a relabel is not', () async {
    final first = await _client(_TreeCarrier());
    final second = await _client(_TreeCarrier());
    final original = gitConnectionKey(HostConnection(client: first, isLocal: false, hostId: 'same'));
    expect(
      original,
      gitConnectionKey(HostConnection(client: first, label: 'renamed', isLocal: false, hostId: 'same')),
    );
    expect(original, isNot(gitConnectionKey(HostConnection(client: second, isLocal: false, hostId: 'same'))));
    expect(gitConnectionKey(null), isNull);
  });

  test('a watched git state re-reads on its own while the chip is on screen', () async {
    final client = await _client(_TreeCarrier(terminals: true));
    final service = _ProbeService({client: 'main'});
    _SwitchConnection.initial = HostConnection(client: client, isLocal: true);
    final container = ProviderContainer(
      overrides: [
        activeConnectionProvider.overrideWith((ref) => ref.watch(_switchConnection)),
        gitHostServiceProvider.overrideWithValue(service),
        gitRefreshIntervalProvider.overrideWithValue(const Duration(milliseconds: 25)),
      ],
    );
    addTearDown(container.dispose);
    const scope = GitScope.session('s', workspacePath: '/w');
    final subscription = container.listen(gitBranchProvider(scope), (_, _) {});
    addTearDown(subscription.close);

    expect((await container.read(gitBranchProvider(scope).future)).branch, 'main');
    final before = service.calls;
    // A commit in another terminal needs no workspace watch frame.
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(service.calls, greaterThan(before));
  });

  test('a new client on the same Host re-reads the branch; a relabel does not', () async {
    final first = await _client(_TreeCarrier(terminals: true));
    final second = await _client(_TreeCarrier(terminals: true));
    final service = _ProbeService({first: 'main', second: 'develop'});
    _SwitchConnection.initial = HostConnection(client: first, isLocal: false, hostId: 'same');
    final container = ProviderContainer(
      overrides: [
        activeConnectionProvider.overrideWith((ref) => ref.watch(_switchConnection)),
        gitHostServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);
    const scope = GitScope.session('s', workspacePath: '/w');
    // Keep the autoDispose provider alive across the reconnect.
    final subscription = container.listen(gitBranchProvider(scope), (_, _) {});
    addTearDown(subscription.close);

    expect((await container.read(gitBranchProvider(scope).future)).branch, 'main');
    final afterFirst = service.calls;

    container.read(_switchConnection.notifier).use(
          HostConnection(client: first, label: 'renamed', isLocal: false, hostId: 'same'),
        );
    expect((await container.read(gitBranchProvider(scope).future)).branch, 'main');
    expect(service.calls, afterFirst, reason: 'a label change keeps the same client');

    container.read(_switchConnection.notifier).use(
          HostConnection(client: second, isLocal: false, hostId: 'same'),
        );
    expect((await container.read(gitBranchProvider(scope).future)).branch, 'develop');
    expect(service.calls, greaterThan(afterFirst));
  });
}
