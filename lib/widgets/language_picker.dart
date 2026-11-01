import 'package:connect_app/l10n/l10n.dart';
import 'package:connect_app/services/locale_controller.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// Lets the user pick the app language: the device language, or one of the
/// supported languages, each listed in its own name.
Future<void> showLanguagePicker(BuildContext context) async {
  final l10n = context.l10n;
  final controller = LocaleController.instance;
  final current = controller.choice.value;
  // What "Device language" means right now, e.g. "Français".
  final deviceName = lookupAppLocalizations(AppLanguages.resolve(
          WidgetsBinding.instance.platformDispatcher.locale))
      .languageName;
  final picked = await showModalBottomSheet<_LanguageChoice>(
    context: context,
    backgroundColor: AppColors.canvas,
    showDragHandle: true,
    builder: (ctx) {
      Widget option(_LanguageChoice choice, String title, String? subtitle) {
        final selected = choice.locale?.languageCode == current?.languageCode;
        return ListTile(
          key:
              Key('language_option_${choice.locale?.languageCode ?? 'system'}'),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: selected
              ? const Icon(Icons.check, color: AppColors.primary)
              : null,
          onTap: () => Navigator.pop(ctx, choice),
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(l10n.languagePickerTitle,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(l10n.languagePickerNote,
                  style: const TextStyle(color: AppColors.muted)),
            ),
            option(const _LanguageChoice(null), l10n.languageSystemDefault,
                l10n.languageSystemDefaultSubtitle(deviceName)),
            // Each language is listed in its own name.
            for (final locale in AppLanguages.supported)
              option(_LanguageChoice(locale),
                  lookupAppLocalizations(locale).languageName, null),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  if (picked == null) return;
  await controller.select(picked.locale);
}

/// A globe button that opens [showLanguagePicker]; used before sign-in.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('language_button'),
      tooltip: context.l10n.settingsLanguage,
      icon: const Icon(Icons.language, color: AppColors.text),
      onPressed: () => showLanguagePicker(context),
    );
  }
}

class _LanguageChoice {
  /// Null follows the device language.
  final Locale? locale;
  const _LanguageChoice(this.locale);
}
