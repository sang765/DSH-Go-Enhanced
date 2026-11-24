// Git repository input parsing and Host-side git commands (clone, checkout,
// branch state) used by the new-chat Workspace sheet, the branch picker and the
// composer's branch chip.
//
// Parsing is pure and deliberately strict: everything that reaches a shell is
// either a validated repository slug or a validated URL, so a pasted string
// can never inject a second command. Commands run in a terminal on the active
// Host — the phone never touches its own filesystem, and Remote Hosts run
// against their own disk through the same API.

import 'dart:async';

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Host used when the input is a short `owner/repo` slug.
enum GitHost {
  github('github.com', 'GitHub'),
  gitlab('gitlab.com', 'GitLab');

  const GitHost(this.domain, this.label);

  final String domain;
  final String label;
}

/// A validated repository source and the folder name git will create.
class GitRepoSpec {
  const GitRepoSpec({required this.url, required this.name, required this.host});

  final String url;
  final String name;
  final GitHost host;

  String get cloneCommand => "git clone --depth 1 '$url' '$name'";
}

final _segment = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._~-]*$');
final _sshUrl = RegExp(r'^git@([A-Za-z0-9.-]+):([A-Za-z0-9._~/-]+?)(?:\.git)?$');
final _ansi = RegExp(r'\x1B(?:\[[0-9;?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1B\\))');

/// A git ref name safe to hand to a shell: no spaces, quotes, globs or dashes
/// that a command could read as an option.
final _refName = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._/-]*$');

bool isValidGitRefName(String name) =>
    name.length <= 200 && _refName.hasMatch(name) && !name.contains('..') && !name.endsWith('/');

/// Accepts a full `https://` / `git@host:` URL or an `owner/repo` slug.
/// Returns null for anything ambiguous; the sheet shows one fixed hint then.
GitRepoSpec? parseGitRepoInput(String raw, GitHost shortHost) {
  final input = raw.trim();
  if (input.isEmpty || input.length > 512) return null;

  final ssh = _sshUrl.firstMatch(input);
  if (ssh != null) {
    final domain = ssh.group(1)!;
    final path = ssh.group(2)!;
    if (!_validHost(domain) || !_validPath(path)) return null;
    final name = _nameFromPath(path);
    if (name == null) return null;
    return GitRepoSpec(
      url: 'git@$domain:$path.git',
      name: name,
      host: domain.contains('gitlab') ? GitHost.gitlab : GitHost.github,
    );
  }

  if (input.contains('://')) {
    final uri = Uri.tryParse(input);
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return null;
    final domain = uri.host;
    final defaultPort = uri.scheme == 'https' ? 443 : 80;
    if (!_validHost(domain) || uri.userInfo.isNotEmpty || (uri.port != 0 && uri.port != defaultPort)) return null;
    if (uri.query.isNotEmpty || uri.fragment.isNotEmpty) return null;
    final path = uri.path.replaceFirst(RegExp(r'^/'), '').replaceFirst(RegExp(r'\.git$'), '');
    if (!_validPath(path)) return null;
    final name = _nameFromPath(path);
    if (name == null) return null;
    return GitRepoSpec(
      url: '${uri.scheme}://$domain/$path.git',
      name: name,
      host: domain.contains('gitlab') ? GitHost.gitlab : GitHost.github,
    );
  }

  if (!_validPath(input)) return null;
  final name = _nameFromPath(input);
  if (name == null) return null;
  return GitRepoSpec(url: 'https://${shortHost.domain}/$input.git', name: name, host: shortHost);
}

bool _validHost(String host) =>
    host.length <= 253 && RegExp(r'^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$').hasMatch(host);

bool _validPath(String path) {
  final parts = path.split('/');
  return parts.length >= 2 &&
      parts.length <= 8 &&
      parts.every((part) => part.isNotEmpty && part != '.' && part != '..' && _segment.hasMatch(part));
}

String? _nameFromPath(String path) {
  final last = path.split('/').last.replaceFirst(RegExp(r'\.git$'), '');
  return _segment.hasMatch(last) ? last : null;
}

/// One command's exit code, the short ANSI-stripped tail of what it wrote
/// ([output], what a person reads), and everything it wrote ([raw], what a
/// structured command is parsed from).
class GitCommandResult {
  const GitCommandResult({required this.exitCode, required this.output, this.raw = ''});

  final int exitCode;
  final String output;
  final String raw;

  bool get ok => exitCode == 0;
}

/// What one structured git probe reports (see [gitProbeCommand]).
class GitProbeState {
  const GitProbeState({
    required this.branch,
    required this.changedFiles,
    required this.branches,
    required this.remotes,
    required this.worktree,
  });

  /// Current branch; null on a detached HEAD.
  final String? branch;

  /// Entries `git status --porcelain` lists, 0 when the tree is clean.
  final int changedFiles;

  /// Local branch names.
  final List<String> branches;

  /// Remote-tracking names, e.g. `origin/develop`; the symbolic `origin/HEAD`
  /// is dropped.
  final List<String> remotes;

  /// True in a linked worktree (`git worktree add`), where `.git` is a file.
  final bool worktree;

  bool get dirty => changedFiles > 0;
}

/// Prints one machine-readable line describing the repository in the terminal's
/// folder, or nothing at all outside one.
///
/// Raw on purpose: `%(refname:short)` and `$?` must reach the shell as written.
/// Ref names cannot contain a space, so the two branch lists join on one.
const String gitProbeCommand =
    r'''git rev-parse --git-dir >/dev/null 2>&1 && cd "$(git rev-parse --show-toplevel 2>/dev/null)" && printf '\n__DSH_GITSTATE__%s|%s|%s|%s|%s\n' "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" "$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')" "$(git for-each-ref --count=200 --format='%(refname:short)' refs/heads 2>/dev/null | tr '\n' ' ')" "$(git for-each-ref --count=200 --format='%(refname:short)' refs/remotes 2>/dev/null | tr '\n' ' ')" "$([ "$(git rev-parse --git-dir 2>/dev/null)" = "$(git rev-parse --git-common-dir 2>/dev/null)" ] && printf main || printf worktree)"''';

final _probeMarker = RegExp(r'__DSH_GITSTATE__([^\r\n]*)');

/// A payload field: ref names, list separators, one digit run. Deliberately
/// narrow, because the terminal echoes the command that printed the line and
/// the echoed source is full of `%s`, quotes and `$(`.
final _probeField = RegExp(r'^[A-Za-z0-9._/ -]*$');

/// Reads the line [gitProbeCommand] prints; null when there is none — no
/// repository in that folder, or a terminal that could not run git.
GitProbeState? parseGitProbe(String text) {
  GitProbeState? found;
  for (final match in _probeMarker.allMatches(text)) {
    final parts = match.group(1)!.split('|');
    if (parts.length != 5 || !parts.every(_probeField.hasMatch)) continue;
    // `--abbrev-ref HEAD` answers HEAD itself when it points at no branch.
    final branch = parts[0].isEmpty || parts[0] == 'HEAD' ? null : parts[0];
    if (branch != null && !isValidGitRefName(branch)) continue;
    final changed = int.tryParse(parts[1]);
    if (changed == null || changed < 0) continue;
    found = GitProbeState(
      branch: branch,
      changedFiles: changed,
      branches: _probeRefs(parts[2]),
      remotes: _probeRefs(parts[3]).where((name) => !name.endsWith('/HEAD')).toList(),
      worktree: parts[4] == 'worktree',
    );
  }
  return found;
}

List<String> _probeRefs(String field) => [
  for (final name in field.split(' '))
    if (name.isNotEmpty && isValidGitRefName(name)) name,
];

class GitCommandException implements Exception {
  const GitCommandException(this.code, [this.detail = '']);

  final String code;
  final String detail;

  @override
  String toString() => detail.isEmpty ? code : '$code: $detail';
}

/// Runs one shell command in a Host terminal, with a unique marker appended so
/// the exit code can be read back reliably: [run] in a throwaway session (clone,
/// checkout), [runIn] in a session the caller already has (the branch probe).
///
/// The caller owns authority: [stillCurrent] is rechecked at every await, so a
/// host switch or a closed sheet cannot let a stale command register anything.
class GitHostTerminal {
  const GitHostTerminal();

  static const marker = '__DSH_GIT__';
  static final _markerPattern = RegExp('$marker:([0-9]+)');

  Future<GitCommandResult> run({
    required DshClient client,
    String? cwd,
    String? workspaceId,
    required String command,
    required bool Function() stillCurrent,
    void Function(String)? onProgress,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    if (!client.supportsTerminals) throw const GitCommandException('terminalUnavailable');
    if (!stillCurrent()) throw const GitCommandException('revoked');

    final session = await client.createSession(cwd: cwd, workspaceId: workspaceId);
    final sessionId = session.sessionId;
    if (sessionId.isEmpty) throw const GitCommandException('sessionCreateFailed');
    try {
      return await _execute(
        client: client,
        sessionId: sessionId,
        command: command,
        stillCurrent: stillCurrent,
        onProgress: onProgress,
        timeout: timeout,
      );
    } finally {
      if (await _canDelete(client)) {
        try {
          await client.deleteSessionPermanently(sessionId);
        } on Object {
          // Cleanup is best effort; a session left on the Host is not a failure.
        }
      }
    }
  }

  /// Runs one command in a terminal of a session the caller already has. The
  /// read-only probe uses this: it runs inside the conversation it describes,
  /// so watching a branch never creates a session that the drawer would show.
  Future<GitCommandResult> runIn({
    required DshClient client,
    required String sessionId,
    required String command,
    required bool Function() stillCurrent,
    void Function(String)? onProgress,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!client.supportsTerminals) throw const GitCommandException('terminalUnavailable');
    if (!stillCurrent()) throw const GitCommandException('revoked');
    return _execute(
      client: client,
      sessionId: sessionId,
      command: command,
      stillCurrent: stillCurrent,
      onProgress: onProgress,
      timeout: timeout,
      // One probe line carries every ref name; a busy repository easily
      // outgrows the interactive buffer. Long-running commands keep the
      // small tail window, this one needs its whole answer.
      maxBuffer: 1 << 20,
    );
  }

  Future<GitCommandResult> _execute({
    required DshClient client,
    required String sessionId,
    required String command,
    required bool Function() stillCurrent,
    required void Function(String)? onProgress,
    required Duration timeout,
    int maxBuffer = 16384,
  }) async {
    final terminalId = newTerminalId();
    StreamSubscription<TerminalFrame>? frames;
    TerminalAttachment? attachment;
    var closed = false;

    Future<void> cleanup() async {
      if (closed) return;
      closed = true;
      await frames?.cancel();
      await attachment?.close();
      try {
        await client.closeTerminal(sessionId, terminalId);
      } on Object {
        // A lost host cleans its own terminals; cleanup is best effort.
      }
      frames = null;
      attachment = null;
    }

    try {
      if (!stillCurrent()) throw const GitCommandException('revoked');
      await client.createTerminal(sessionId, id: terminalId, cols: 100, rows: 30);
      final environment = await client.terminalEnvironment(sessionId);
      attachment = client.attachTerminal(sessionId, terminalId, environment: environment);
      final done = Completer<int>();
      final buffer = StringBuffer();
      frames = attachment!.frames.listen(
        (frame) {
          if (frame is TerminalSnapshot && frame.writable) {
            final wrapped = "$command; printf '\\n$marker:%s\\n' \"\$?\"\n";
            if (!attachment!.write(wrapped)) {
              if (!done.isCompleted) done.completeError(const GitCommandException('terminalNotWritable'));
            }
            return;
          }
          if (frame is TerminalOutput) {
            final text = frame.data.replaceAll(_ansi, '');
            buffer.write(text);
            if (buffer.length > maxBuffer) buffer.clear();
            final clean = text.replaceAll(RegExp(r'\r'), '').trim();
            if (clean.isNotEmpty) onProgress?.call(clean.length > 160 ? clean.substring(clean.length - 160) : clean);
            final match = _markerPattern.firstMatch(buffer.toString());
            if (match != null && !done.isCompleted) done.complete(int.tryParse(match.group(1)!) ?? -1);
            return;
          }
          if (frame is TerminalStatus && frame.info.state != TerminalProcessState.running && !done.isCompleted) {
            done.complete(-1);
          }
        },
        onError: (Object error) {
          if (!done.isCompleted) done.completeError(error);
        },
      );
      final exitCode = await done.future.timeout(
        timeout,
        onTimeout: () => throw const GitCommandException('timeout'),
      );
      if (!stillCurrent()) throw const GitCommandException('revoked');
      final text = buffer.toString();
      return GitCommandResult(exitCode: exitCode, output: gitCommandTail(text), raw: text);
    } on TimeoutException {
      throw const GitCommandException('timeout');
    } finally {
      await cleanup();
    }
  }

  Future<bool> _canDelete(DshClient client) async {
    try {
      return await client.supportsSessionDeletion();
    } on Object {
      return false;
    }
  }
}

/// The last few meaningful lines of a command's output, without the marker.
String gitCommandTail(String text) {
  final lines = text
      .replaceAll(_ansi, '')
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('${GitHostTerminal.marker}:'))
      .toList();
  return lines.skip(lines.length > 6 ? lines.length - 6 : 0).join('\n');
}

/// Result of one clone attempt.
class GitCloneOutcome {
  const GitCloneOutcome({required this.path, required this.exitCode, required this.output});

  final String path;
  final int exitCode;
  final String output;

  bool get ok => exitCode == 0;
}

/// Result of one branch switch: `ok`, or git's own refusal message.
class GitCheckoutOutcome {
  const GitCheckoutOutcome({required this.branch, required this.exitCode, required this.output});

  final String branch;
  final int exitCode;
  final String output;

  bool get ok => exitCode == 0;
}

/// Clone, branch switching and branch state against the active Host.
abstract interface class GitHostService {
  Future<GitCloneOutcome> clone({
    required DshClient client,
    required GitRepoSpec spec,
    required String parentPath,
    required bool Function() stillCurrent,
    void Function(String)? onProgress,
  });

  /// Switches to [branch]; with [create], makes it first (`git checkout -b`).
  Future<GitCheckoutOutcome> checkout({
    required DshClient client,
    required String cwd,
    required String branch,
    required bool Function() stillCurrent,
    bool create = false,
  });

  /// The folder's full git state, or null when the folder is not a repository
  /// (or the terminal could not answer) — the caller keeps what it already had.
  /// Runs inside [sessionId], the conversation the state describes.
  Future<GitProbeState?> probe({
    required DshClient client,
    required String sessionId,
    required bool Function() stillCurrent,
  });
}

final gitHostServiceProvider = Provider<GitHostService>((_) => const HostGitService());

class HostGitService implements GitHostService {
  const HostGitService();

  @override
  Future<GitCloneOutcome> clone({
    required DshClient client,
    required GitRepoSpec spec,
    required String parentPath,
    required bool Function() stillCurrent,
    void Function(String)? onProgress,
  }) async {
    final target = parentPath.endsWith('/') ? '$parentPath${spec.name}' : '$parentPath/${spec.name}';
    final result = await const GitHostTerminal().run(
      client: client,
      cwd: parentPath,
      command: spec.cloneCommand,
      stillCurrent: stillCurrent,
      onProgress: onProgress,
    );
    return GitCloneOutcome(path: target, exitCode: result.exitCode, output: result.output);
  }

  @override
  Future<GitCheckoutOutcome> checkout({
    required DshClient client,
    required String cwd,
    required String branch,
    required bool Function() stillCurrent,
    bool create = false,
  }) async {
    if (!isValidGitRefName(branch)) throw const GitCommandException('invalidRef');
    final result = await const GitHostTerminal().run(
      client: client,
      cwd: cwd,
      command: create ? "git checkout -b '$branch'" : "git checkout '$branch'",
      stillCurrent: stillCurrent,
    );
    return GitCheckoutOutcome(branch: branch, exitCode: result.exitCode, output: result.output);
  }

  @override
  Future<GitProbeState?> probe({
    required DshClient client,
    required String sessionId,
    required bool Function() stillCurrent,
  }) async {
    final GitCommandResult result;
    try {
      result = await const GitHostTerminal().runIn(
        client: client,
        sessionId: sessionId,
        command: gitProbeCommand,
        stillCurrent: stillCurrent,
      );
    } on GitCommandException {
      // No terminal, no git, or the caller moved on: the file probe stands.
      return null;
    }
    return parseGitProbe(result.raw);
  }
}
