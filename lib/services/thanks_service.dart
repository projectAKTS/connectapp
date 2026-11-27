import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/services/app_telemetry.dart';
import 'package:connect_app/services/content_filter.dart';
import 'package:connect_app/services/helperly_test_runtime.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Thank-you notes after a chat.
///
/// A note lives at `thanks/{chatId}_{fromUid}`: one per person per chat.
/// Rules allow it only when the recipient wrote in that chat (they helped),
/// forbid edits, and let the sender or the recipient delete it. Notes show
/// on the recipient's profile without the sender's name.
class ThanksService {
  ThanksService._();

  static final ThanksService instance = ThanksService._();

  static const int maxTextLength = 280;

  CollectionReference<Map<String, dynamic>> get _col =>
      HelperlyTestRuntime.firestore.collection('thanks');

  static String noteId(String chatId, String fromUid) => '${chatId}_$fromUid';

  // Words people use to say thanks in a chat; when one appears, the chat
  // offers to put it on the helper's profile.
  static final RegExp _thanksWords = RegExp(
    r'\b(thank(s|ful)?|thx|ty|tysm|merci|gracias|danke|grazie|obrigad[oa])\b'
    r'|te[sş]ekk[uü]r|sa[gğ] ?ol|شكرا',
    caseSensitive: false,
  );

  static bool soundsLikeThanks(String text) => _thanksWords.hasMatch(text);

  // Chats where the offer was closed, for this app session.
  final Set<String> _dismissedPrompts = <String>{};

  bool isPromptDismissed(String chatId) => _dismissedPrompts.contains(chatId);

  void dismissPrompt(String chatId) => _dismissedPrompts.add(chatId);

  /// Whether the signed-in user has a note in [chatId], live.
  Stream<bool> watchThanked(String chatId) {
    final uid = HelperlyTestRuntime.currentUid ?? '';
    if (uid.isEmpty) return Stream<bool>.value(false);
    return _col.doc(noteId(chatId, uid)).snapshots().map((s) => s.exists);
  }

  /// Notes to [uid], newest first, with their doc ids. Sorted here rather
  /// than with orderBy so the query needs no composite index.
  Stream<List<MapEntry<String, Map<String, dynamic>>>> notesTo(String uid,
      {int limit = 50}) {
    return _col.where('toUid', isEqualTo: uid).limit(limit).snapshots().map(
      (s) {
        final list = s.docs.map((d) => MapEntry(d.id, d.data())).toList();
        int millis(Map<String, dynamic> m) {
          final t = m['createdAt'];
          return t is Timestamp ? t.millisecondsSinceEpoch : 0;
        }

        list.sort((a, b) => millis(b.value).compareTo(millis(a.value)));
        return list;
      },
    );
  }

  /// Whether the signed-in user already thanked someone in [chatId].
  Future<bool> hasThanked(String chatId) async {
    final uid = HelperlyTestRuntime.currentUid ?? '';
    if (uid.isEmpty) return false;
    final snap = await _col.doc(noteId(chatId, uid)).get();
    return snap.exists;
  }

  Future<void> send({
    required String chatId,
    required String toUid,
    required String text,
  }) async {
    final uid = HelperlyTestRuntime.currentUid ?? '';
    if (uid.isEmpty) return;
    await _col.doc(noteId(chatId, uid)).set({
      'chatId': chatId,
      'fromUid': uid,
      'toUid': toUid,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> remove(String noteId) => _col.doc(noteId).delete();

  /// Asks for a short note, then saves it. Returns true when saved.
  Future<bool> thankWithSheet(
    BuildContext context, {
    required String chatId,
    required String toUid,
    required String toName,
    String initialText = '',
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    bool already;
    try {
      already = await hasThanked(chatId);
    } catch (_) {
      already = false;
    }
    if (already) {
      messenger.showSnackBar(
          SnackBar(content: Text(l10n.thanksAlreadySent(toName))));
      return false;
    }
    if (!context.mounted) return false;
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.canvas,
      showDragHandle: true,
      builder: (_) => _ThanksSheet(toName: toName, initialText: initialText),
    );
    if (text == null || text.trim().isEmpty) return false;
    try {
      await send(chatId: chatId, toUid: toUid, text: text);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.thanksSaveFailed)));
      return false;
    }
    AppTelemetry.event('thanks_sent', {'length': text.trim().length});
    messenger.showSnackBar(SnackBar(content: Text(l10n.thanksSent)));
    return true;
  }
}

class _ThanksSheet extends StatefulWidget {
  final String toName;
  final String initialText;
  const _ThanksSheet({required this.toName, this.initialText = ''});

  @override
  State<_ThanksSheet> createState() => _ThanksSheetState();
}

class _ThanksSheetState extends State<_ThanksSheet> {
  late final TextEditingController _text =
      TextEditingController(text: widget.initialText.trim());
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    if (!ContentFilter.isAllowed(text)) {
      setState(() => _error = context.l10n.contentRejected);
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.thanksTitle(widget.toName),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.thanksShownOnProfile,
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('thanks_text'),
                controller: _text,
                autofocus: true,
                maxLength: ThanksService.maxTextLength,
                maxLines: 4,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.thanksHint,
                  errorText: _error,
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('thanks_submit'),
                onPressed: _text.text.trim().isEmpty ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l10n.thanksSend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
