import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Custom Markdown element builder for fenced code blocks.
/// Provides syntax highlighting via flutter_highlight and a copy button.
class CodeBlockBuilder extends MarkdownElementBuilder {
  final bool showLineNumbers;

  CodeBlockBuilder({this.showLineNumbers = false});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final language = element.attributes['class']?.replaceFirst('language-', '') ?? '';
    final code = element.textContent;

    return _CodeBlockWidget(
      code: code,
      language: language,
      showLineNumbers: showLineNumbers,
    );
  }
}

class _CodeBlockWidget extends StatefulWidget {
  final String code;
  final String language;
  final bool showLineNumbers;

  const _CodeBlockWidget({
    required this.code,
    required this.language,
    required this.showLineNumbers,
  });

  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  bool _copied = false;

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (mounted) {
      setState(() => _copied = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _copied = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header with language label and copy button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFEEEEEE),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: <Widget>[
                if (widget.language.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.language,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF616161),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _copyToClipboard,
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 16,
                  ),
                  label: Text(_copied ? 'Copied' : 'Copy'),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          // Code body
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildCodeBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeBody() {
    final codeTextStyle = const TextStyle(
      fontFamily: 'monospace',
      fontSize: 13,
      height: 1.5,
    );
    final codeChild = widget.language.isNotEmpty
        ? HighlightView(
            widget.code,
            language: widget.language,
            theme: githubTheme,
            padding: EdgeInsets.fromLTRB(
              widget.showLineNumbers ? 12 : 16,
              16,
              16,
              16,
            ),
            textStyle: codeTextStyle,
          )
        : Padding(
            padding: EdgeInsets.fromLTRB(
              widget.showLineNumbers ? 12 : 16,
              16,
              16,
              16,
            ),
            child: Text(
              widget.code,
              style: codeTextStyle,
            ),
          );

    if (!widget.showLineNumbers) {
      return codeChild;
    }

    final lines = widget.code.split('\n');
    if (widget.language.isNotEmpty) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(12, 16, 10, 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF0EEE9),
              border: Border(
                right: BorderSide(color: Color(0xFFE0E0E0)),
              ),
            ),
            child: Text(
              _buildLineNumberText(lines.length),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.5,
                color: Color(0xFF8A8178),
              ),
            ),
          ),
          codeChild,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.fromLTRB(12, 16, 10, 16),
          decoration: const BoxDecoration(
            color: Color(0xFFF0EEE9),
            border: Border(
              right: BorderSide(color: Color(0xFFE0E0E0)),
            ),
          ),
          child: Text(
            _buildLineNumberText(lines.length),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF8A8178),
            ),
          ),
        ),
        codeChild,
      ],
    );
  }

  String _buildLineNumberText(int lineCount) {
    return List<String>.generate(lineCount, (index) => '${index + 1}').join('\n');
  }
}
