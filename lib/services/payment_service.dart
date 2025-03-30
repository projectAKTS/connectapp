import 'dart:math';

class PaymentService {
  /// Simulate a payment (Replace this with actual integration later)
  Future<bool> processPayment({required double amount}) async {
    await Future.delayed(const Duration(seconds: 2));
    return Random().nextBool();
  }
}
