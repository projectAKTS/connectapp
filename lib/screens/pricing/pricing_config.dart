/// Centralized pricing and monetization configuration
/// Currency: CAD (Canadian Dollars)
///
/// This ensures consistent pricing across all parts of the app:
/// - Consultation booking
/// - Checkout / Stripe integration
/// - Earnings / analytics
/// - Display in UI components

class PricingConfig {
  /// Available consultation durations in minutes
  static const List<int> durations = [5, 10, 15, 30, 45, 60];

  /// Seeker-facing retail prices (in CAD) for AUDIO sessions
  static const Map<int, double> audioPrices = {
    5: 2.99,
    10: 4.49,
    15: 6.99,
    30: 12.99,
    45: 17.99,
    60: 22.99,
  };

  /// Video sessions cost 30% more (premium tier)
  static double getVideoPrice(int duration) {
    final base = audioPrices[duration] ?? 0;
    return double.parse((base * 1.3).toStringAsFixed(2));
  }

  /// Platform fee percentage (default 20%)
  static const double platformFee = 0.20;

  /// Returns the price for given duration & call type
  static double getPrice(int duration, String callType) {
    if (callType == 'video') return getVideoPrice(duration);
    return audioPrices[duration] ?? 0;
  }

  /// Returns the helper payout (after platform fee)
  static double getHelperPayout(int duration, String callType) {
    final price = getPrice(duration, callType);
    final payout = price * (1 - platformFee);
    return double.parse(payout.toStringAsFixed(2));
  }

  /// Returns the platform’s share for a given session
  static double getPlatformCut(int duration, String callType) {
    final price = getPrice(duration, callType);
    final cut = price * platformFee;
    return double.parse(cut.toStringAsFixed(2));
  }

  /// Returns the rate per minute (rounded)
  static double getRatePerMinute(int duration, String callType) {
    final price = getPrice(duration, callType);
    if (duration <= 0) return 0;
    return double.parse((price / duration).toStringAsFixed(2));
  }

  /// Summary for logs or analytics
  static Map<String, dynamic> getSummary(int duration, String callType) {
    return {
      'duration': '$duration min',
      'callType': callType,
      'price (CAD)': getPrice(duration, callType),
      'rate/min (CAD)': getRatePerMinute(duration, callType),
      'platform fee %': platformFee * 100,
      'helper payout (CAD)': getHelperPayout(duration, callType),
      'platform cut (CAD)': getPlatformCut(duration, callType),
    };
  }
}
