import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/l10n/value_labels.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// A field showing the languages someone speaks; tapping it opens a
/// multi-select list of [ValueLabels.languageCodes]. Values are ISO codes.
class SpokenLanguagesField extends StatelessWidget {
  final List<String> codes;
  final ValueChanged<List<String>> onChanged;
  final Color? fill;

  const SpokenLanguagesField({
    super.key,
    required this.codes,
    required this.onChanged,
    this.fill,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = codes.map((c) => ValueLabels.language(l10n, c)).join(', ');
    return InkWell(
      key: const Key('spoken_languages_field'),
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await showSpokenLanguagesSheet(context, codes);
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: fill ?? AppColors.card,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          suffixIcon:
              const Icon(Icons.expand_more, color: AppColors.muted, size: 20),
        ),
        child: Text(
          text.isEmpty ? l10n.spokenLanguagesHint : text,
          style: text.isEmpty
              ? const TextStyle(color: AppColors.muted, fontSize: 13)
              : const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text),
        ),
      ),
    );
  }
}

/// Multi-select of spoken languages. Returns the new codes, or null when
/// dismissed. Selected codes keep their order; new ones are appended.
Future<List<String>?> showSpokenLanguagesSheet(
    BuildContext context, List<String> initial) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    showDragHandle: true,
    builder: (ctx) => _SpokenLanguagesSheet(initial: initial),
  );
}

class _SpokenLanguagesSheet extends StatefulWidget {
  final List<String> initial;
  const _SpokenLanguagesSheet({required this.initial});

  @override
  State<_SpokenLanguagesSheet> createState() => _SpokenLanguagesSheetState();
}

class _SpokenLanguagesSheetState extends State<_SpokenLanguagesSheet> {
  late final List<String> _selected = List.of(widget.initial);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Alphabetical in the app language, so French users find "Turc" under T.
    final codes = List.of(ValueLabels.languageCodes)
      ..sort((a, b) => ValueLabels.language(l10n, a)
          .toLowerCase()
          .compareTo(ValueLabels.language(l10n, b).toLowerCase()));
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(l10n.spokenLanguagesLabel,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(l10n.spokenLanguagesNote,
                  style: const TextStyle(color: AppColors.muted)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final code in codes)
                    CheckboxListTile(
                      key: Key('spoken_language_$code'),
                      value: _selected.contains(code),
                      activeColor: AppColors.primary,
                      title: Text(ValueLabels.language(l10n, code)),
                      onChanged: (on) => setState(() {
                        on == true
                            ? _selected.add(code)
                            : _selected.remove(code);
                      }),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: FilledButton(
                key: const Key('spoken_languages_done'),
                onPressed: () => Navigator.pop(context, _selected),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l10n.commonDone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
