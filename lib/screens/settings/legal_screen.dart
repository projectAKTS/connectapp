import 'package:connect_app/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Shows one of the in-app legal or safety texts.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.title, required this.markdown});

  final String title;
  final String markdown;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Markdown(
          data: markdown,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: const TextStyle(
                fontSize: 15, height: 1.45, color: AppColors.text),
            listBullet: const TextStyle(fontSize: 15, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}
