import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_chat/features/chat/code_block_builder.dart';

void main() {
  group('Markdown and code block rendering widget tests', () {
    testWidgets('assistant message with markdown renders', (tester) async {
      const markdown = '# Hello\n\nThis is **bold** text.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MarkdownBody(data: markdown),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    testWidgets('code block builder renders fenced code with line numbers', (tester) async {
      const markdown = '```dart\nvoid main() {}\nprint("x");\n```';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownBody(
              data: markdown,
              builders: {
                'code': CodeBlockBuilder(showLineNumbers: true),
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.text('1\n2'), findsOneWidget);
    });
  });
}
