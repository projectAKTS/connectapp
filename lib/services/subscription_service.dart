import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class SubscriptionService {
  static final InAppPurchase _iap = InAppPurchase.instance;

  static const subscriptionIds = <String>['premium_monthly', 'premium_yearly'];
  static const consumableIds = <String>['credits_5min', 'credits_30min', 'credits_60min'];

  static Future<bool> init() async {
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('⚠️ In-app purchases unavailable');
      return false;
    }
    return true;
  }

  static Future<List<ProductDetails>> fetchSubscriptions() async {
    final response = await _iap.queryProductDetails(subscriptionIds.toSet());
    if (response.error != null) throw response.error!;
    return response.productDetails;
  }

  static Future<List<ProductDetails>> fetchCredits() async {
    final response = await _iap.queryProductDetails(consumableIds.toSet());
    if (response.error != null) throw response.error!;
    return response.productDetails;
  }

  static Future<void> buySubscription(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  static Future<void> buyCredits(ProductDetails product) async {
    final param = PurchaseParam(productDetails: product);
    await _iap.buyConsumable(purchaseParam: param, autoConsume: true);
  }

  static Future<void> restore() async {
    await _iap.restorePurchases();
  }

  static void setupListener(void Function(List<PurchaseDetails>) onUpdate) {
    _iap.purchaseStream.listen(
      onUpdate,
      onError: (e) => debugPrint('Purchase error: $e'),
    );
  }
}
