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
}
