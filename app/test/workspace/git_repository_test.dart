import 'package:dsh_app/state/git_repository_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseGitRepoInput', () {
    test('accepts owner/repo with the selected short-name host', () {
      final github = parseGitRepoInput('sang765/DSH-Go-Enhanced', GitHost.github)!;
      expect(github.url, 'https://github.com/sang765/DSH-Go-Enhanced.git');
      expect(github.name, 'DSH-Go-Enhanced');
      expect(github.host, GitHost.github);

      final gitlab = parseGitRepoInput('  group/sub/repo  ', GitHost.gitlab)!;
      expect(gitlab.url, 'https://gitlab.com/group/sub/repo.git');
      expect(gitlab.name, 'repo');
      expect(gitlab.host, GitHost.gitlab);
    });

    test('accepts https and ssh urls and keeps their own host', () {
      final https = parseGitRepoInput('https://github.com/sang765/LeviDroid-Modder.git', GitHost.gitlab)!;
      expect(https.host, GitHost.github);
      expect(https.url, 'https://github.com/sang765/LeviDroid-Modder.git');
      expect(https.name, 'LeviDroid-Modder');

      final ssh = parseGitRepoInput('git@gitlab.com:group/repo.git', GitHost.github)!;
      expect(ssh.host, GitHost.gitlab);
      expect(ssh.url, 'git@gitlab.com:group/repo.git');
      expect(ssh.name, 'repo');
    });

    test('rejects ambiguous, injection-shaped or incomplete input', () {
      for (final input in [
        '',
        'repo',
        'owner/repo; rm -rf /',
        "owner/repo' && echo x",
        'https://github.com/owner/repo?token=x',
        'git@github.com:owner/repo;echo',
        'ftp://github.com/owner/repo',
        'http://user:pw@github.com/owner/repo',
      ]) {
        expect(parseGitRepoInput(input, GitHost.github), isNull, reason: input);
      }
    });
  });

  group('parseGitProbe', () {
    test('reads the line the probe prints', () {
      final state = parseGitProbe('\n__DSH_GITSTATE__main|0|main develop|origin/main origin/develop|main\n')!;
      expect(state.branch, 'main');
      expect(state.changedFiles, 0);
      expect(state.dirty, isFalse);
      expect(state.branches, ['main', 'develop']);
      expect(state.remotes, ['origin/main', 'origin/develop']);
      expect(state.worktree, isFalse);
    });

    test('keeps a detached worktree with uncommitted changes', () {
      final state = parseGitProbe('__DSH_GITSTATE__HEAD|3|main|origin/main|worktree')!;
      expect(state.branch, isNull);
      expect(state.changedFiles, 3);
      expect(state.dirty, isTrue);
      expect(state.worktree, isTrue);
    });

    test('drops the symbolic remote HEAD and keeps nested remote names', () {
      final state = parseGitProbe('__DSH_GITSTATE__main|0|main|origin/HEAD origin/main origin/feature/x|main')!;
      expect(state.remotes, ['origin/main', 'origin/feature/x']);
    });

    test('ignores the echoed command and prefers the answer that followed it', () {
      // The terminal prints the command it was given, so the marker appears a
      // first time inside its own source.
      const echoed = r'''printf '\n__DSH_GITSTATE__%s|%s|%s|%s|%s\n' "$(git rev-parse --abbrev-ref HEAD)"''';
      final state = parseGitProbe('$echoed\n__DSH_GITSTATE__feature/x|1|feature/x|origin/main|main\n')!;
      expect(state.branch, 'feature/x');
      expect(state.changedFiles, 1);
      expect(state.branches, ['feature/x']);
    });

    test('reports nothing outside a repository', () {
      expect(parseGitProbe(''), isNull);
      expect(parseGitProbe('fatal: not a git repository\n'), isNull);
      expect(parseGitProbe('__DSH_GITSTATE__main|0|main'), isNull);
      expect(parseGitProbe('__DSH_GITSTATE__main|x|main||main'), isNull);
    });
  });
}
