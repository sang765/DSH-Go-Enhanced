// Pasted Markdown in your own message renders, and the original text is one tap away.

import 'package:dsh_app/ui/chat/mention/mention_chip.dart';
import 'package:dsh_app/ui/chat/render/markdown_body.dart';
import 'package:dsh_app/ui/chat/widgets/user_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

void main() {
  test('only obvious markdown blocks switch the bubble', () {
    expect(looksLikeMarkdown('just *a* prompt with # and |'), isFalse);
    expect(looksLikeMarkdown('**bold** inline'), isFalse);
    expect(looksLikeMarkdown('```dart\nprint(1);\n```'), isTrue);
    expect(looksLikeMarkdown('# Heading\nbody'), isTrue);
    expect(looksLikeMarkdown('[link](https://example.com)'), isTrue);
  });

  testWidgets('markdown mentions follow the canonical grammar', (tester) async {
    usePhoneView(tester);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: Center(child: UserBubble(text: '# hi @alice and mail a@example.com\n@docs/shot.png')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Bare @word and an email stay text; only the path-like token is a chip.
    expect(find.byType(MentionChip), findsOneWidget);
    expect(find.text('shot.png'), findsOneWidget);
  });

  testWidgets('rendered markdown can be switched back to the raw text', (tester) async {
    usePhoneView(tester);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: Center(child: UserBubble(text: '```dart\nprint(1);\n```')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('查看原文'), findsOneWidget);
    await tester.tap(find.text('查看原文'));
    await tester.pumpAndSettle();
    expect(find.byType(MarkdownBody), findsNothing);
    expect(find.text('以 Markdown 显示'), findsOneWidget);
  });
}
