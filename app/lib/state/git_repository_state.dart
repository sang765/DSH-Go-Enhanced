// Git repository input parsing and the Host-side clone operation used by the
// new-chat Workspace sheet.
//
// Parsing is pure and deliberately strict: everything that reaches a shell is
// either a validated repository slug or a validated URL, so a pasted string
// can never inject a second command. The clone itself runs in a throwaway
// session's terminal on the active Host — the phone never touches its own
// filesystem, and Remote Hosts clone on their own disk through the same API.

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
final _marker = RegExp(r'__DSH_GIT_CLONE__:([0-9]+)');
final _ansi = RegExp(r'\x1B(?:\[[0-9;?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1B\\))');

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

/// Result of one clone attempt. [output] is the short, ANSI-stripped tail the
/// sheet shows when [exitCode] is non-zero.
class GitCloneOutcome {
  const GitCloneOutcome({required this.path, required this.exitCode, required this.output});

  final String path;
  final int exitCode;
  final String output;

  bool get ok => exitCode == 0;
}

class GitCloneException implements Exception {
  const GitCloneException(this.code, [this.detail = '']);

  final String code;
  final String detail;

  @override
  String toString() => detail.isEmpty ? code : '$code: $detail';
}

/// Runs `git clone` in a throwaway session's terminal on the active Host.
/// The caller owns authority: [stillCurrent] is rechecked at every await, so
/// a host switch or a closed sheet cannot let a stale clone register a folder.
abstract interface class GitCloneService {
  Future<GitCloneOutcome> clone({
    required DshClient client,
    required GitRepoSpec spec,
    required String parentPath,
    required bool Function() stillCurrent,
    void Function(String)? onProgress,
  });
}

final gitCloneServiceProvider = Provider<GitCloneService>((_) => const HostGitCloneService());

class HostGitCloneService implements GitCloneService {
  const HostGitCloneService();

  @override
  Future<GitCloneOutcome> clone({
    required DshClient client,
    required GitRepoSpec spec,
    required String parentPath,
    required bool Function() stillCurrent,
    void Function(String)? onProgress,
  }) async {
    if (!client.supportsTerminals) throw const GitCloneException('terminalUnavailable');
    if (!stillCurrent()) throw const GitCloneException('revoked');

    final session = await client.createSession(cwd: parentPath);
    final sessionId = session.sessionId;
    if (sessionId.isEmpty) throw const GitCloneException('sessionCreateFailed');
    final terminalId = newTerminalId();
    final target = _join(parentPath, spec.name);
    String? lastOutput;
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

    if (!stillCurrent()) {
      await cleanup();
      throw const GitCloneException('revoked');
    }

    try {
      await client.createTerminal(sessionId, id: terminalId, cols: 100, rows: 30);
      final environment = await client.terminalEnvironment(sessionId);
      attachment = client.attachTerminal(sessionId, terminalId, environment: environment);
      final done = Completer<int>();
      final buffer = StringBuffer();
      frames = attachment!.frames.listen(
        (frame) {
          if (frame is TerminalSnapshot && frame.writable) {
            final command = '${spec.cloneCommand}; printf \'\\n__DSH_GIT_CLONE__:%s\\n\' "\$?"\n';
            if (!attachment!.write(command)) {
              if (!done.isCompleted) done.completeError(const GitCloneException('terminalNotWritable'));
            }
            return;
          }
          if (frame is TerminalOutput) {
            final text = frame.data.replaceAll(_ansi, '');
            buffer.write(text);
            if (buffer.length > 16384) buffer.clear();
            final clean = text.replaceAll(RegExp(r'\r'), '').trim();
            if (clean.isNotEmpty) onProgress?.call(clean.length > 160 ? clean.substring(clean.length - 160) : clean);
            final match = _marker.firstMatch(buffer.toString());
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
        const Duration(minutes: 10),
        onTimeout: () => throw const GitCloneException('timeout'),
      );
      if (!stillCurrent()) throw const GitCloneException('revoked');
      lastOutput = buffer.toString();
      return GitCloneOutcome(path: target, exitCode: exitCode, output: _tail(lastOutput));
    } on TimeoutException {
      throw const GitCloneException('timeout');
    } finally {
      await cleanup();
      if (await _canDelete(client)) {
        try {
          await client.deleteSessionPermanently(sessionId);
        } on Object {
          // Cleanup is best effort; a session left on the Host is not a failed clone.
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

  String _join(String parent, String name) => parent.endsWith('/') ? '$parent$name' : '$parent/$name';

  String _tail(String text) {
    final lines = text
        .replaceAll(_ansi, '')
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('__DSH_GIT_CLONE__:'))
        .toList();
    return lines.skip(lines.length > 6 ? lines.length - 6 : 0).join('\n');
  }
}
