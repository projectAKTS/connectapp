import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:connect_app/utils/time_utils.dart';
import 'package:connect_app/theme/tokens.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;
  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);

  // ---- Pull "**Something Post**" from the first non-empty line.
  (String?, String) _extractBadgeAndBody(String raw) {
    final lines = raw.split('\n');
    int idx = 0;
    while (idx < lines.length && lines[idx].trim().isEmpty) idx++;
    if (idx >= lines.length) return (null, raw);

    final first = lines[idx].trim();
    final reg = RegExp(r'^\*\*(.+?)\*\*$'); // **Something**
    final m = reg.firstMatch(first);
    if (m != null && m.group(1) != null) {
      final label = m.group(1)!.trim();
      if (label.toLowerCase().endsWith(' post')) {
        final rest = [...lines]..removeAt(idx);
        if (idx < rest.length && rest[idx].trim().isEmpty) {
          rest.removeAt(idx);
        }
        return (label, rest.join('\n').trimLeft());
      }
    }
    return (null, raw);
  }

  // Simple markdown (**bold** only)
  TextSpan _parseSimpleMarkdownToSpan(
    String text, {
    required TextStyle base,
    required TextStyle strong,
  }) {
    final spans = <TextSpan>[];
    int i = 0;
    while (i < text.length) {
      final start = text.indexOf('**', i);
      if (start == -1) {
        spans.add(TextSpan(text: text.substring(i), style: base));
        break;
      }
      if (start > i) spans.add(TextSpan(text: text.substring(i, start), style: base));
      final end = text.indexOf('**', start + 2);
      if (end == -1) {
        spans.add(TextSpan(text: text.substring(start), style: base));
        break;
      }
      spans.add(TextSpan(text: text.substring(start + 2, end), style: strong));
      i = end + 2;
    }
    return TextSpan(children: spans, style: base);
  }

  Widget _postTypeBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Smaller “template” minimum height:
    final screenH = MediaQuery.of(context).size.height;
    final double minCardHeight = screenH * 0.30 < 220 ? 220 : screenH * 0.30;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        title: const Text('Post Detail'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('posts').doc(postId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Post not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final dt = parseFirestoreTimestamp(data['timestamp']);
          final date = dt != null ? DateFormat.yMMMd().add_jm().format(dt) : 'Unknown date';
          final content = (data['content'] ?? '').toString();
          final (maybeBadge, body) = _extractBadgeAndBody(content);
          final badge = maybeBadge ?? 'Quick Post';

          final base = const TextStyle(fontSize: 16, height: 1.4, color: AppColors.text);
          final strong = const TextStyle(
            fontSize: 16,
            height: 1.4,
            color: AppColors.text,
            fontWeight: FontWeight.w700,
          );
          final span = _parseSimpleMarkdownToSpan(body, base: base, strong: strong);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minCardHeight),
              child: SizedBox(
                width: double.infinity, // fixed left/right edges
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
                    boxShadow: const [AppShadows.soft],
                  ),
                  child: Stack(
                    children: [
                      // Main content with bottom padding for the footer
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 56),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (data['userName'] ?? 'Anonymous').toString(),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),

                            if ((data['imageUrl'] ?? '').toString().isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(data['imageUrl']),
                              ),
                              const SizedBox(height: 12),
                            ],

                            _postTypeBadge(badge),
                            const SizedBox(height: 8),
                            RichText(text: span),
                          ],
                        ),
                      ),

                      // Footer pinned to bottom
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Text(
                          'Posted on $date',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
