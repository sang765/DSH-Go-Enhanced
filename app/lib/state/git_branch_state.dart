// Which git branch the folder behind a conversation (or a workspace a new
// conversation will start in) is on, and how to switch it.
//
// Detection is read-only and session-free: it looks for `.git` through
// `workspaceFiles`, reads `HEAD` for the current branch and the refs for the
// list. Switching needs a process, so it runs `git checkout` in a throwaway
// Host session's terminal ([GitHostService.checkout]); git itself refuses a
// checkout that would overwrite local changes, and that refusal is shown.

import 'dart:async';

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connection_state.dart';
import 'git_repository_state.dart' show isValidGitRefName;

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
  const GitBranchInfo({required this.isRepo, this.branch, this.branches = const []});

  static const notRepo = GitBranchInfo(isRepo: false);

  final bool isRepo;

  /// Current branch; null on a detached HEAD (see [detached]).
  final String? branch;

  /// Local branches, current one included.
  final List<String> branches;

  bool get detached => isRepo && branch == null;
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

/// Local branches listed in `.git/packed-refs` (what a fresh clone has).
List<String> parsePackedRefsHeads(String text) {
  const prefix = 'refs/heads/';
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

/// Reads the folder behind [scope]; [isRepo] false whenever the Host does not
/// answer or the folder has no `.git` directory.
Future<GitBranchInfo> readGitBranch(DshClient client, GitScope scope) async {
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
  // A `.git` file is a linked worktree; its gitdir lives outside the
  // workspace, so this probe leaves it alone rather than guessing a path.
  if (git == null || git.type != DshWorkspaceEntryType.directory) return GitBranchInfo.notRepo;

  final branch = gitBranchFromHead(await _readOrEmpty(client, scope.id, '.git/HEAD'));
  final names = <String>{
    ...parsePackedRefsHeads(await _readOrEmpty(client, scope.id, '.git/packed-refs')),
  };
  await _collectLooseHeads(client, scope.id, '.git/refs/heads', '', names, 0);
  if (branch != null) names.add(branch);
  final branches = names.toList()..sort();
  return GitBranchInfo(isRepo: true, branch: branch, branches: branches);
}

Future<String> _readOrEmpty(DshClient client, String scope, String path) async {
  try {
    return (await client.readWorkspaceText(scope, path, limit: 64)).text;
  } on Object {
    // A missing or unreadable file simply contributes no refs.
    return '';
  }
}

Future<void> _collectLooseHeads(
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
      await _collectLooseHeads(client, scope, '$path/${entry.name}', '$prefix${entry.name}/', out, depth + 1);
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
/// The first read is one pass; while the UI keeps the provider alive the
/// watched refs below bring it up to date, so a branch the agent (or a
/// terminal) creates or switches shows up without closing the sheet.
final gitBranchProvider = FutureProvider.autoDispose.family<GitBranchInfo, GitScope>((ref, scope) async {
  final client = ref.watch(activeConnectionProvider.select((c) => c.value?.client));
  if (client == null) return GitBranchInfo.notRepo;
  final info = await readGitBranch(client, scope);
  // A folder without a repository has nothing to follow, and a host that
  // cannot watch answers with an error; either way the next open re-reads.
  if (info.isRepo) _followGitRefs(ref, client, scope);
  return info;
});

/// What a branch change can touch: the checked-out branch, the loose refs a
/// new branch creates, and the packed refs a fetch or clone writes.
const gitWatchTargets = ['.git/HEAD', '.git/refs/heads', '.git/packed-refs'];

/// Whether a watch frame means the branch state may have moved.
bool gitWatchNeedsReread(DshWorkspaceWatchFrame frame) => frame is DshWorkspaceWatchChange;

/// Re-reads the scope when one of [gitWatchTargets] changes. A target that is
/// absent (a repository with no packed refs yet) ends only its own watch.
void _followGitRefs(Ref ref, DshClient client, GitScope scope) {
  final subscriptions = <StreamSubscription<DshWorkspaceWatchFrame>>[];
  Timer? pending;
  for (final path in gitWatchTargets) {
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
