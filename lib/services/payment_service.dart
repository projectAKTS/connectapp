import 'dart:math';

class PaymentService {
  /// 🔥 Simulate a payment (Replace this with Stripe/Razorpay)
  Future<bool> processPayment({required double amount}) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate payment processing
    return Random().nextBool(); // Simulate success/failure randomly
  }
}
