import 'package:cloud_functions/cloud_functions.dart';

class PaymentService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Processes payment using the stored payment method (one-click payment).
  /// Returns true if the payment was successful.
  Future<bool> processPayment({
    required double amount,
    required String userId,
  }) async {
    try {
      final callable = _functions.httpsCallable('chargeStoredPaymentMethod');
      final response = await callable.call({
        'userId': userId,
        'amount': amount,
        'currency': 'usd',
      });
      final data = response.data;
      if (data['success'] == true) {
        return true;
      } else {
        print("Payment failed: ${data['error']}");
        return false;
      }
    } catch (error) {
      print("Error processing payment: $error");
      return false;
    }
  }
}
