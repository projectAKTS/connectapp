import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:connect_app/utils/time_utils.dart';
import 'package:connect_app/theme/tokens.dart';

class PostDetailScreen extends StatelessWidget {
  final String postId;
  const PostDetailScreen({Key? key, required this.postId}) : super(key: key);

  (String?, String) _extractBadgeAndBody(String raw) {
    final lines = raw.split('\n');
    int idx = 0;
    while (idx < lines.length && lines[idx].trim().isEmpty) idx++;
    if (idx >= lines.length) return (null, raw);

    final first = lines[idx].trim();
    final reg = RegExp(r'^\*\*(.+?)\*\*$');
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
      if (start > i) {
        spans.add(TextSpan(text: text.substring(i, start), style: base));
      }
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

  List<String> _extractImageUrls(Map<String, dynamic> data) {
    final v = data['imageUrls'];
    if (v is List) {
      return v
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final single = (data['imageUrl'] ?? '').toString().trim();
    if (single.isNotEmpty) return [single];
    return [];
  }

  @override
  Widget build(BuildContext context) {
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
          final date =
              dt != null ? DateFormat.yMMMd().add_jm().format(dt) : 'Unknown date';
          final content = (data['content'] ?? '').toString();
          final (maybeBadge, body) = _extractBadgeAndBody(content);
          final badge = maybeBadge ?? 'Quick Post';

          final base = const TextStyle(
              fontSize: 16, height: 1.4, color: AppColors.text);
          final strong = const TextStyle(
            fontSize: 16,
            height: 1.4,
            color: AppColors.text,
            fontWeight: FontWeight.w700,
          );
          final span =
              _parseSimpleMarkdownToSpan(body, base: base, strong: strong);
          final imageUrls = _extractImageUrls(data);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minCardHeight),
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: const Border.fromBorderSide(
                        BorderSide(color: AppColors.border)),
                    boxShadow: const [AppShadows.soft],
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 56),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (data['userName'] ?? 'Anonymous').toString(),
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            if (imageUrls.isNotEmpty) ...[
                              _DetailMediaCarousel(urls: imageUrls),
                              const SizedBox(height: 12),
                            ],
                            _postTypeBadge(badge),
                            const SizedBox(height: 8),
                            RichText(text: span),
                          ],
                        ),
                      ),
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

class _DetailMediaCarousel extends StatefulWidget {
  final List<String> urls;
  const _DetailMediaCarousel({required this.urls});

  @override
  State<_DetailMediaCarousel> createState() => _DetailMediaCarouselState();
}

class _DetailMediaCarouselState extends State<_DetailMediaCarousel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(widget.urls.first, fit: BoxFit.cover),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: PageView.builder(
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => Image.network(
                widget.urls[i],
                fit: BoxFit.cover,
                loadingBuilder: (c, w, p) =>
                    p == null ? w : Container(color: AppColors.button),
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.button,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image, color: AppColors.muted),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.urls.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 14 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(active ? 0.55 : 0.25),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
