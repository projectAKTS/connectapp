/// Features hidden for the MVP launch.
///
/// - Premium had no server-side entitlement and showed a $0 test plan.
/// - Post boost is a digital good, so the App Store requires IAP; it was
///   paid by Stripe card.
/// - Streak and XP are noise until the core help loop works; the product
///   docs plan them for later phases.
class MvpFeatures {
  MvpFeatures._();

  static const bool premium = false;
  static const bool gamificationStats = false;
}
