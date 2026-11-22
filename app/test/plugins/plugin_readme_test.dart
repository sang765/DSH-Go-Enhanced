import 'package:dsh_app/state/plugins/plugin_readme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const repo = 'https://github.com/SAOS-3624/dsh-see-now.git';

  test('relative README links point at the repository default branch', () {
    final text = resolveReadmeUrls(
      '![shot](docs/shot.png)\n\n[Guide](./GUIDE.md) and [site](https://example.com/x).',
      repositoryUrl: repo,
    );
    expect(
      text,
      contains('![shot](https://raw.githubusercontent.com/SAOS-3624/dsh-see-now/HEAD/docs/shot.png)'),
    );
    expect(text, contains('[Guide](https://raw.githubusercontent.com/SAOS-3624/dsh-see-now/HEAD/GUIDE.md)'));
    expect(text, contains('[site](https://example.com/x)'));
  });

  test('a monorepo directory is kept in front of relative paths', () {
    final text = resolveReadmeUrls('[doc](/docs/a.md)', repositoryUrl: repo, directory: 'packages/app');
    expect(text, contains('https://raw.githubusercontent.com/SAOS-3624/dsh-see-now/HEAD/packages/app/docs/a.md'));
  });

  test('common README HTML becomes Markdown the renderer understands', () {
    final text = normalizeReadme('<p align="center"><img src="a.png"></p><h2>Hi</h2>one<br>two');
    expect(text, contains('![](a.png)'));
    expect(text, contains('## Hi'));
    expect(text, contains('one\ntwo'));
    expect(text, isNot(contains('<p')));
  });

  test('an HTML src with a closing paren cannot inject Markdown', () {
    final text = normalizeReadme('<img src="a) ![x](https://evil">');
    expect(text, isNot(contains('![x]')));
    expect(text, isNot(contains('https://evil')));
  });

  test('absolute remote and data images become links, relative ones stay images', () {
    final text = normalizeReadme(
      '<img src="https://tracker.example/pixel.png"> ![d](data:image/png;base64,AAAA) ![shot](docs/shot.png)',
    );
    expect(text, contains('[](https://tracker.example/pixel.png)'));
    expect(text, contains('[d](data:image/png;base64,AAAA)'));
    expect(text, contains('![shot](docs/shot.png)'));
  });

  test('non-GitHub repositories leave the README alone', () {
    const md = '![x](img/x.png)';
    expect(resolveReadmeUrls(md, repositoryUrl: 'https://gitlab.com/a/b'), md);
    expect(resolveReadmeUrls(md), md);
  });
}
