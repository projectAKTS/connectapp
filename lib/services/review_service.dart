import 'package:connect_app/services/app_telemetry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/services/content_filter.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Ratings for finished consultations.
///
/// A review lives at `reviews/{consultationId}`, so each consultation gets at
/// most one. Rules let only the person who booked it write it, after its start
/// time; the server then updates the helper's `rating` and `ratingCount`.
class ReviewService {
  ReviewService._();

  static final ReviewService instance = ReviewService._();

  static const int maxTextLength = 500;

  /// The consultation ids the signed-in user has already reviewed.
  Stream<Set<String>> reviewedConsultationIds() {
    final uid = HelperlyTestRuntime.currentUid ?? '';
    if (uid.isEmpty) return Stream.value(const <String>{});
    return HelperlyTestRuntime.firestore
        .collection('reviews')
        .where('reviewerUid', isEqualTo: uid)
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toSet());
  }

  /// Reviews of [helperUid], newest first. Sorted here rather than with
  /// orderBy so the query needs no composite index; MVP volumes are small.
  Stream<List<Map<String, dynamic>>> reviewsOf(String helperUid,
      {int limit = 50}) {
    return HelperlyTestRuntime.firestore
        .collection('reviews')
        .where('helperUid', isEqualTo: helperUid)
        .limit(limit)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => d.data()).toList();
      int millis(Map<String, dynamic> m) {
        final t = m['createdAt'];
        return t is Timestamp ? t.millisecondsSinceEpoch : 0;
      }

      list.sort((a, b) => millis(b).compareTo(millis(a)));
      return list;
    });
  }

  Future<void> submit({
    required String consultationId,
    required String helperUid,
    required int stars,
    String text = '',
  }) async {
    final uid = HelperlyTestRuntime.currentUid ?? '';
    if (uid.isEmpty) return;
    await HelperlyTestRuntime.firestore
        .collection('reviews')
        .doc(consultationId)
        .set({
      'consultationId': consultationId,
      'reviewerUid': uid,
      'helperUid': helperUid,
      'stars': stars,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Asks for stars and an optional comment, then saves. Returns true when
  /// saved.
  Future<bool> rateWithSheet(
    BuildContext context, {
    required String consultationId,
    required String helperUid,
    required String helperName,
  }) async {
    final result = await showModalBottomSheet<_RateResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      showDragHandle: true,
      builder: (_) => _RateSheet(helperName: helperName),
    );
    if (result == null) return false;
    try {
      await submit(
        consultationId: consultationId,
        helperUid: helperUid,
        stars: result.stars,
        text: result.text,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save your rating. Please try again.'),
        ));
      }
      return false;
    }
    AppTelemetry.event('consultation_rated', {'stars': result.stars});
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Thanks for rating your session.'),
      ));
    }
    return true;
  }
}

class _RateResult {
  final int stars;
  final String text;
  const _RateResult(this.stars, this.text);
}

class _RateSheet extends StatefulWidget {
  final String helperName;
  const _RateSheet({required this.helperName});

  @override
  State<_RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<_RateSheet> {
  final TextEditingController _text = TextEditingController();
  int _stars = 0;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    if (_stars == 0) return;
    final text = _text.text.trim();
    if (!ContentFilter.isAllowed(text)) {
      setState(() => _error = ContentFilter.rejectionMessage);
      return;
    }
    Navigator.pop(context, _RateResult(_stars, text));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'How was your session with ${widget.helperName}?',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your rating and comment are shown on their profile.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      key: Key('rate_star_$i'),
                      iconSize: 36,
                      tooltip: '$i star${i == 1 ? '' : 's'}',
                      onPressed: () => setState(() => _stars = i),
                      icon: Icon(
                        i <= _stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color:
                            i <= _stars ? AppColors.primary : AppColors.muted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _text,
                maxLength: ReviewService.maxTextLength,
                maxLines: 4,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'What helped? (optional)',
                  errorText: _error,
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('rate_submit'),
                onPressed: _stars == 0 ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('Submit rating'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
