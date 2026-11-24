// Git repository input parsing and Host-side git commands (clone, checkout)
// used by the new-chat Workspace sheet and the branch picker.
//
// Parsing is pure and deliberately strict: everything that reaches a shell is
// either a validated repository slug or a validated URL, so a pasted string
// can never inject a second command. Commands run in a throwaway session's
// terminal on the active Host — the phone never touches its own filesystem,
// and Remote Hosts run against their own disk through the same API.

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

/// One command's exit code and the short, ANSI-stripped tail of what it wrote.
class GitCommandResult {
  const GitCommandResult({required this.exitCode, required this.output});

  final int exitCode;
  final String output;

  bool get ok => exitCode == 0;
}

class GitCommandException implements Exception {
  const GitCommandException(this.code, [this.detail = '']);

  final String code;
  final String detail;

  @override
  String toString() => detail.isEmpty ? code : '$code: $detail';
}

/// Runs one shell command inside a throwaway Host session's terminal, with a
/// unique marker appended so the exit code can be read back reliably.
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
            if (buffer.length > 16384) buffer.clear();
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
      return GitCommandResult(exitCode: exitCode, output: gitCommandTail(buffer.toString()));
    } on TimeoutException {
      throw const GitCommandException('timeout');
    } finally {
      await cleanup();
      if (await _canDelete(client)) {
        try {
          await client.deleteSessionPermanently(sessionId);
        } on Object {
          // Cleanup is best effort; a session left on the Host is not a failure.
        }
      }
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

/// Clone and branch switching against the active Host.
abstract interface class GitHostService {
  Future<GitCloneOutcome> clone({
    required DshClient client,
    required GitRepoSpec spec,
    required String parentPath,
    required bool Function() stillCurrent,
    void Function(String)? onProgress,
  });

  Future<GitCheckoutOutcome> checkout({
    required DshClient client,
    required String cwd,
    required String branch,
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
  }) async {
    if (!isValidGitRefName(branch)) throw const GitCommandException('invalidRef');
    final result = await const GitHostTerminal().run(
      client: client,
      cwd: cwd,
      command: "git checkout '$branch'",
      stillCurrent: stillCurrent,
    );
    return GitCheckoutOutcome(branch: branch, exitCode: result.exitCode, output: result.output);
  }
}
