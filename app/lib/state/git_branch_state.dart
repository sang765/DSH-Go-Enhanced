// Which git branch the folder behind a conversation (or a workspace a new
// conversation will start in) is on, and how to switch it.
//
// Reading happens in two tiers, cheapest first:
//   * files — `.git/HEAD`, the loose refs and `packed-refs`. Needs no process,
//     so it is all a new conversation's workspace can offer and it works on a
//     Host with no terminal.
//   * one `git` run in the conversation's own terminal — the same state plus
//     what only git itself knows: uncommitted changes, whether the folder is a
//     linked worktree, and the remote-tracking branches. A conversation is the
//     only scope with a session to run it in.
// Switching needs a process too, so it runs `git checkout` in a terminal
// ([GitHostService.checkout]); git refuses a switch that would throw away local
// changes, and that refusal is shown as it came.

import 'dart:async';

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection_state.dart';
import 'git_repository_state.dart'
    show GitHostService, gitHostServiceProvider, isValidGitRefName;

/// What a git probe is keyed by: a conversation (its session id) or the
/// workspace a not-yet-created conversation will start in.
enum GitScopeKind { session, workspace }

class GitScope {
  const GitScope._(this.kind, this.id, this.workspacePath);

  const GitScope.session(String id, {String? workspacePath}) : this._(GitScopeKind.session, id, workspacePath);
  const GitScope.workspace(String id, {String? workspacePath}) : this._(GitScopeKind.workspace, id, workspacePath);

  final GitScopeKind kind;
  final String id;

  /// The Host-side folder, when the caller already knows it (a new chat's
  /// workspace); a session's cwd is asked of the Host instead.
  final String? workspacePath;

  @override
  bool operator ==(Object other) =>
      other is GitScope && other.kind == kind && other.id == id && other.workspacePath == workspacePath;

  @override
  int get hashCode => Object.hash(kind, id, workspacePath);

  @override
  String toString() => '${kind.name}:$id';
}

/// What the folder reports. [isRepo] false covers "not a repository" and "the
/// Host would not answer" alike: both hide the branch controls, and a later
/// read tries again.
class GitBranchInfo {
  const GitBranchInfo({
    required this.isRepo,
    this.branch,
    this.branches = const [],
    this.remotes = const [],
    this.worktree = false,
    this.changedFiles,
  });

  static const notRepo = GitBranchInfo(isRepo: false);

  final bool isRepo;

  /// Current branch; null on a detached HEAD (see [detached]) and while only
  /// files could be read in a linked worktree, whose git directory sits
  /// outside the folder.
  final String? branch;

  /// Local branches, current one included.
  final List<String> branches;

  /// Remote-tracking names, e.g. `origin/develop`; the symbolic `origin/HEAD`
  /// is dropped.
  final List<String> remotes;

  /// True when the folder is a linked worktree (`git worktree add`), where
  /// `.git` is a file instead of a directory.
  final bool worktree;

  /// Entries git reports as changed; null while only files could be read.
  final int? changedFiles;

  bool get detached => isRepo && branch == null;

  bool get dirty => (changedFiles ?? 0) > 0;
}

/// `refs/heads/<name>` from a `.git/HEAD` file; null when HEAD is detached or
/// points somewhere that is not a local branch.
String? gitBranchFromHead(String text) {
  final line = text.split(RegExp(r'\r?\n')).first.trim();
  const prefix = 'ref: refs/heads/';
  if (!line.startsWith(prefix)) return null;
  final name = line.substring(prefix.length).trim();
  return isValidGitRefName(name) ? name : null;
}

/// Ref names in `.git/packed-refs` that start with [prefix].
List<String> parsePackedRefs(String text, String prefix) {
  final names = <String>[];
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#') || line.startsWith('^')) continue;
    final space = line.indexOf(' ');
    if (space < 0) continue;
    final ref = line.substring(space + 1).trim();
    if (!ref.startsWith(prefix)) continue;
    final name = ref.substring(prefix.length);
    if (isValidGitRefName(name)) names.add(name);
  }
  return names;
}

/// Local branches listed in `.git/packed-refs` (what a fresh clone has).
List<String> parsePackedRefsHeads(String text) => parsePackedRefs(text, 'refs/heads/');

/// Remote-tracking branches listed in `.git/packed-refs`.
List<String> parsePackedRefsRemotes(String text) => parsePackedRefs(text, 'refs/remotes/');

/// The git directory a `.git` *file* names (a linked worktree or a submodule),
/// or null when the file is not one.
String? gitDirFromFile(String text) {
  final line = text.split(RegExp(r'\r?\n')).first.trim();
  const prefix = 'gitdir: ';
  if (!line.startsWith(prefix)) return null;
  final path = line.substring(prefix.length).trim();
  return path.isEmpty ? null : path;
}

/// The worktree's git directory as a path inside the folder, when the probe can
/// reach it: relative, and with no way back out of the folder. An absolute
/// `gitdir` (what git writes by default: `…/<main>/.git/worktrees/<name>`) is
/// outside the listing this probe can read, so the caller falls back to the
/// terminal tier instead of guessing.
String? reachableGitDir(String path) {
  if (path.startsWith('/')) return null;
  if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path)) return null;
  final parts = path.split('/');
  if (parts.any((part) => part.isEmpty || part == '.' || part == '..')) return null;
  return parts.join('/');
}

/// Reads the folder behind [scope] with the fullest tier available: one git
/// command for a conversation on a Host with terminals, file reads otherwise.
/// A failed probe falls through to the files, so a Host that cannot answer git
/// still offers branch switching.
Future<GitBranchInfo> readGitBranch(
  DshClient client,
  GitScope scope, {
  GitHostService? service,
  bool Function() stillCurrent = _alwaysCurrent,
}) async {
  // A conversation can run git in its own terminal. That answers everything —
  // branch, local and remote refs, worktree and dirty — in one command, so the
  // file tier would only add RPCs here. A new chat has no session to run it in,
  // and a Host without terminals falls back to reading the files below.
  if (service != null && scope.kind == GitScopeKind.session && client.supportsTerminals) {
    final probe = await service.probe(client: client, sessionId: scope.id, stillCurrent: stillCurrent);
    if (probe != null && stillCurrent()) {
      return GitBranchInfo(
        isRepo: true,
        branch: probe.branch,
        branches: probe.branches,
        remotes: probe.remotes,
        worktree: probe.worktree,
        changedFiles: probe.changedFiles,
      );
    }
  }
  return _readGitFiles(client, scope);
}

bool _alwaysCurrent() => true;

Future<GitBranchInfo> _readGitFiles(DshClient client, GitScope scope) async {
  final DshWorkspaceListing root;
  try {
    root = await client.listWorkspace(scope.id, '');
  } on Object {
    return GitBranchInfo.notRepo;
  }
  DshWorkspaceEntry? git;
  for (final entry in root.entries) {
    if (entry.name == '.git') {
      git = entry;
      break;
    }
  }
  if (git == null) return GitBranchInfo.notRepo;
  if (git.type == DshWorkspaceEntryType.directory) {
    return _readGitDir(client, scope.id, '.git', worktree: false);
  }
  // A `.git` file is a linked worktree: the git directory it names holds the
  // same HEAD and refs, one folder along.
  final dir = gitDirFromFile(await _readOrEmpty(client, scope.id, '.git'));
  final reachable = dir == null ? null : reachableGitDir(dir);
  if (reachable == null) return const GitBranchInfo(isRepo: true, worktree: true);
  return _readGitDir(client, scope.id, reachable, worktree: true);
}

Future<GitBranchInfo> _readGitDir(
  DshClient client,
  String scope,
  String dir, {
  required bool worktree,
}) async {
  final packed = await _readOrEmpty(client, scope, '$dir/packed-refs');
  final branch = gitBranchFromHead(await _readOrEmpty(client, scope, '$dir/HEAD'));
  final heads = <String>{...parsePackedRefsHeads(packed)};
  await _collectLooseRefs(client, scope, '$dir/refs/heads', '', heads, 0);
  if (branch != null) heads.add(branch);
  final remotes = <String>{...parsePackedRefsRemotes(packed)};
  await _collectLooseRefs(client, scope, '$dir/refs/remotes', '', remotes, 0);
  return GitBranchInfo(
    isRepo: true,
    branch: branch,
    branches: heads.toList()..sort(),
    remotes: remotes.where((name) => !name.endsWith('/HEAD')).toList()..sort(),
    worktree: worktree,
  );
}

Future<String> _readOrEmpty(DshClient client, String scope, String path) async {
  try {
    return (await client.readWorkspaceText(scope, path, limit: 64)).text;
  } on Object {
    // A missing or unreadable file simply contributes no refs.
    return '';
  }
}

Future<void> _collectLooseRefs(
  DshClient client,
  String scope,
  String path,
  String prefix,
  Set<String> out,
  int depth,
) async {
  if (depth > 3) return;
  final DshWorkspaceListing listing;
  try {
    listing = await client.listWorkspace(scope, path);
  } on Object {
    return;
  }
  for (final entry in listing.entries) {
    if (entry.name == 'HEAD') continue;
    if (entry.type == DshWorkspaceEntryType.directory) {
      await _collectLooseRefs(client, scope, '$path/${entry.name}', '$prefix${entry.name}/', out, depth + 1);
    } else if (isValidGitRefName('$prefix${entry.name}')) {
      out.add('$prefix${entry.name}');
    }
  }
}

/// The folder to run git in: the workspace's own path, else the
/// conversation's directory as the Host reports it.
Future<String?> gitScopeCwd(DshClient client, GitScope scope) async {
  final known = scope.workspacePath;
  if (known != null && known.isNotEmpty) return known;
  if (scope.kind != GitScopeKind.session) return null;
  try {
    return (await client.terminalEnvironment(scope.id)).cwd;
  } on Object {
    return null;
  }
}

/// Live branch state of one scope.
///
/// The first read runs both tiers; while the UI keeps the provider alive the
/// watched paths below bring it up to date, so a branch the agent (or a
/// terminal) creates or switches shows up without closing the sheet.
final gitBranchProvider = FutureProvider.autoDispose.family<GitBranchInfo, GitScope>((ref, scope) async {
  final client = ref.watch(activeConnectionProvider.select((c) => c.value?.client));
  if (client == null) return GitBranchInfo.notRepo;
  final generation = client.mux.generation;
  bool current() => ref.mounted && client.mux.generation == generation;
  final info = await readGitBranch(client, scope, service: ref.read(gitHostServiceProvider), stillCurrent: current);
  // A folder without a repository has nothing to follow, and a host that
  // cannot watch answers with an error; either way the next open re-reads.
  if (info.isRepo && ref.mounted) _followGitRefs(ref, client, scope, info);
  return info;
});

/// What a change in the repository can touch: the checked-out branch, the loose
/// refs a new branch or a fetch creates, the packed refs it rewrites, and the
/// index whose changes are what "uncommitted" means.
const gitWatchTargets = ['.git/HEAD', '.git/refs/heads', '.git/refs/remotes', '.git/packed-refs', '.git/index'];

/// The paths to watch in the workspace root. A linked worktree keeps its git
/// directory outside the folder, so its `.git` file is the only thing here to
/// follow; the terminal tier still reads its branch on every re-read.
List<String> gitWatchTargetsFor(GitBranchInfo info) => info.worktree ? const ['.git'] : gitWatchTargets;

/// Whether a watch frame means the branch state may have moved.
bool gitWatchNeedsReread(DshWorkspaceWatchFrame frame) => frame is DshWorkspaceWatchChange;

/// Re-reads the scope when one of [gitWatchTargetsFor] [info] changes. A target
/// that is absent (a repository with no packed refs yet) ends only its own
/// watch.
void _followGitRefs(Ref ref, DshClient client, GitScope scope, GitBranchInfo info) {
  final subscriptions = <StreamSubscription<DshWorkspaceWatchFrame>>[];
  Timer? pending;
  for (final path in gitWatchTargetsFor(info)) {
    subscriptions.add(
      client.watchWorkspace(scope.id, path).listen(
        (frame) {
          if (!gitWatchNeedsReread(frame)) return;
          // A checkout or a merge writes several refs in a row; one re-read
          // after the dust settles is enough.
          pending?.cancel();
          pending = Timer(const Duration(milliseconds: 150), () {
            if (ref.mounted) ref.invalidateSelf();
          });
        },
        onError: (Object _) {},
        cancelOnError: true,
      ),
    );
  }
  ref.onDispose(() {
    pending?.cancel();
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
  });
}