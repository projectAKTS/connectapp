// lib/screens/pricing/pricing_config.dart
import 'dart:math';

class PricingConfig {
  /// Finalized durations (minutes)
  static const List<int> durations = [5, 10, 15, 30, 45, 60];

  /// PDF: Video is +30% over audio. :contentReference[oaicite:2]{index=2}
  static const double videoMultiplier = 1.30;

  /// PDF: Helper net ~80%, platform ~20%. :contentReference[oaicite:3]{index=3}
  static const double helperShare = 0.80;
  static const double platformShare = 0.20;

  /// Audio base prices (CAD) from the finalized pricing table. :contentReference[oaicite:4]{index=4}
  static const Map<int, double> _audioBase = {
    5: 2.99,
    10: 4.49,
    15: 6.99,
    30: 12.99,
    45: 17.99,
    60: 22.99,
  };

  /// Some video values in the PDF have cents rounding (e.g. 15 min = 9.09, 45 = 23.39).
  /// We keep an explicit table to match the doc exactly. :contentReference[oaicite:5]{index=5}
  static const Map<int, double> _videoExact = {
    5: 3.89,
    10: 5.89,
    15: 9.09,
    30: 16.89,
    45: 23.39,
    60: 29.89,
  };

  static double getPrice(int minutes, String callType) {
    final audio = _audioBase[minutes] ?? 0.0;
    if (callType == 'video') {
      // Use exact values so UI matches the PDFs.
      return _videoExact[minutes] ?? _round2(audio * videoMultiplier);
    }
    return audio;
  }

  static double getHelperPayout(int minutes, String callType) {
    final price = getPrice(minutes, callType);
    return _round2(price * helperShare);
  }

  static double getPlatformFee(int minutes, String callType) {
    final price = getPrice(minutes, callType);
    return _round2(price * platformShare);
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100.0;

  /// Optional: for sorting / safety
  static int clampDuration(int minutes) {
    if (_audioBase.containsKey(minutes)) return minutes;
    return durations.reduce((a, b) => (minutes - a).abs() < (minutes - b).abs() ? a : b);
  }
}
