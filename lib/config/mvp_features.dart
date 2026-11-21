/// Features hidden for the MVP launch.
///
/// - Premium had no server-side entitlement and showed a $0 test plan.
/// - Post boost is a digital good, so the App Store requires IAP; it was
///   paid by Stripe card.
/// - Streak and XP are noise until the core help loop works; the product
///   docs plan them for later phases.
class MvpFeatures {
  MvpFeatures._();

  /// Payments can be exercised only by an explicitly opted-in staging build.
  /// A production build cannot expose payment features through dart-defines.
  static const String _environment =
      String.fromEnvironment('HELPERLY_ENV', defaultValue: 'production');
  static const bool paymentsEnabled = _environment == 'staging' &&
      bool.fromEnvironment('MVP_PAYMENTS_ENABLED', defaultValue: false);

  static const bool subscriptionsEnabled = paymentsEnabled &&
      bool.fromEnvironment('MVP_SUBSCRIPTIONS_ENABLED', defaultValue: false);
  static const bool premium = subscriptionsEnabled;
  static const bool gamificationStats = false;

  /// Paid bookings have a second, staging-only opt-in. Both this flag and the
  /// server's MVP_PAYMENTS_ENABLED + PAID_SESSIONS_ENABLED gates must be on.
  /// Direct audio/video calls and messaging stay free.
  static const bool paidSessions = paymentsEnabled &&
      bool.fromEnvironment('PAID_SESSIONS', defaultValue: false);
}
