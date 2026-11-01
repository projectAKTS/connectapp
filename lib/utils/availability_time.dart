import 'package:flutter/material.dart';

/// Helper availability is stored as text, e.g. "9:00 AM–5:00 PM", and
/// read by every installed build. It is always written in this fixed
/// English 12-hour form, whatever the app language; screens show it with
/// [TimeOfDay.format] in the user's language.
class AvailabilityTime {
  AvailabilityTime._();

  static const String separator = '–';

  static String store(TimeOfDay start, TimeOfDay end) =>
      '${_fixed(start)}$separator${_fixed(end)}';

  static String _fixed(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  /// Parses a stored range written by any build: "9:00 AM–5:00 PM",
  /// "09:00–17:00", "14 h 05–18 h 00". Null when unreadable.
  static (TimeOfDay, TimeOfDay)? parse(String stored) {
    final parts = stored.split(separator);
    if (parts.length != 2) return null;
    final start = parseTime(parts[0]);
    final end = parseTime(parts[1]);
    return (start == null || end == null) ? null : (start, end);
  }

  static TimeOfDay? parseTime(String time) {
    final m = RegExp(r'(\d{1,2})\s*(?::|h)\s*(\d{2})').firstMatch(time);
    if (m == null) return null;
    var hour = int.parse(m[1]!);
    final minute = int.parse(m[2]!);
    final lower = time.toLowerCase();
    if (lower.contains('pm') && hour < 12) hour += 12;
    if (lower.contains('am') && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// The device's UTC offset as "GMT-4" or "GMT+5:30", the format the
  /// time zone field already uses. A suggestion only; the user can edit it.
  static String deviceTimeZone([DateTime? now]) {
    final offset = (now ?? DateTime.now()).timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final minutes = abs.inMinutes % 60;
    return 'GMT$sign${abs.inHours}${minutes == 0 ? '' : ':${minutes.toString().padLeft(2, '0')}'}';
  }
}
