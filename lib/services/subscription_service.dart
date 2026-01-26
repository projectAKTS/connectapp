// lib/services/subscription_service.dart
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionService {
  static final InAppPurchase _iap = InAppPurchase.instance;
  static const _subscriptionIds = <String>['premium_monthly', 'premium_yearly'];

  /// Initialize in-app purchases. Returns true if the store is available.
  static Future<bool> init() async {
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('⚠️ In-app purchases unavailable on this device/emulator');
      return false;
    }
    return true;
  }

  /// Fetch subscription products.
  static Future<List<ProductDetails>> fetchSubscriptions() async {
    final response = await _iap.queryProductDetails(_subscriptionIds.toSet());
    if (response.error != null) throw response.error!;
    return response.productDetails;
  }

  /// Buy a subscription (non-consumable).
  static Future<void> buySubscription(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  /// Listen to purchase updates.
  static void setupListener(void Function(List<PurchaseDetails>) onUpdate) {
    _iap.purchaseStream.listen(onUpdate, onError: (e) => debugPrint('Purchase error: $e'));
  }
}
