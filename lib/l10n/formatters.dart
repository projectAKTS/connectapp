import 'package:connect_app/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Dates, times and money in the app language with the device's region:
/// "Oct 31, 2026, 2:05 PM" / "31 oct. 2026, 14 h 05", "$4.99" / "4,99 $".
///
/// Times are shown in the device's time zone; stored timestamps stay UTC.
class AppFormat {
  AppFormat._();

  /// Loads intl's date names for every locale (in memory, no I/O). Flutter
  /// only loads the bare app language ('fr'), not regional data ('fr_CA').
  static Future<void> init() => initializeDateFormatting();

  /// Formatting locale for [context], falling back to the bare language and
  /// then English when intl has no data for the combination.
  static String localeOf(BuildContext context, {Locale? device}) =>
      _supported(AppLanguages.formatLocale(
          Localizations.maybeLocaleOf(context) ?? AppLanguages.fallback,
          device));

  static String _supported(String locale) {
    if (DateFormat.localeExists(locale)) return locale;
    final language = locale.split('_').first;
    if (DateFormat.localeExists(language)) return language;
    return 'en';
  }

  /// Oct 31, 2026
  static String date(BuildContext context, DateTime dt) =>
      DateFormat.yMMMd(localeOf(context)).format(dt.toLocal());

  /// Oct 31, 2026, 2:05 PM
  static String dateTime(BuildContext context, DateTime dt) =>
      DateFormat.yMMMd(localeOf(context)).add_jm().format(dt.toLocal());

  /// Fri, Oct 31 · 2:05 PM
  static String dayTime(BuildContext context, DateTime dt) {
    final locale = localeOf(context);
    final local = dt.toLocal();
    return '${DateFormat.MMMEd(locale).format(local)} · '
        '${DateFormat.jm(locale).format(local)}';
  }

  /// 2:05 PM
  static String time(BuildContext context, DateTime dt) =>
      DateFormat.jm(localeOf(context)).format(dt.toLocal());

  /// $4.99 (en_CA), 4,99 $ (fr_CA), CA$4.99 elsewhere. [decimals] 0 for
  /// whole amounts such as price filters.
  static String money(BuildContext context, num amount,
      {String currency = 'CAD', int? decimals}) {
    final locale = localeOf(context);
    final known = NumberFormat.localeExists(locale) ? locale : 'en';
    // "$" means CAD only to Canadian devices; elsewhere say "CA$".
    final format = currency == 'CAD' && !known.endsWith('_CA')
        ? NumberFormat.currency(
            locale: known,
            name: currency,
            symbol: r'CA$',
            decimalDigits: decimals ?? 2)
        : NumberFormat.simpleCurrency(
            locale: known, name: currency, decimalDigits: decimals);
    return format.format(amount);
  }
}
