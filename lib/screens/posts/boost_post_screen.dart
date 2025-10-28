import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/payment_service.dart';
import '/services/post_service.dart';

class BoostPostScreen extends StatefulWidget {
  final String postId;

  const BoostPostScreen({Key? key, required this.postId}) : super(key: key);

  @override
  State<BoostPostScreen> createState() => _BoostPostScreenState();
}

class _BoostPostScreenState extends State<BoostPostScreen> {
  final PaymentService _paymentService = PaymentService();
  final PostService _postService = PostService();

  int selectedBoostHours = 24;
  bool isProcessing = false;

  Future<void> _boostPost() async {
    setState(() => isProcessing = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to boost a post.')),
      );
      setState(() => isProcessing = false);
      return;
    }

    try {
      // 💳 Process payment via stored card
      final paymentResult = await _paymentService.processPayment(
        amount: _getBoostPrice(selectedBoostHours),
      );

      switch (paymentResult) {
        case PaymentResult.success:
          // 🚀 Boost post after successful payment
          await _postService.boostPost(widget.postId, selectedBoostHours);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Post boosted successfully!')),
          );
          if (mounted) Navigator.pop(context);
          break;

        case PaymentResult.needsSetup:
          // User has no card saved
          final retry = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('No Payment Method'),
              content: const Text(
                  'You don’t have a saved card. Would you like to add one now?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Add Card')),
              ],
            ),
          );
          if (retry == true) {
            await Navigator.pushNamed(context, '/paymentSetup');
          }
          break;

        case PaymentResult.unauthenticated:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Authentication expired. Please log in again.')),
          );
          break;

        case PaymentResult.failed:
        default:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Payment failed. Please check your card or try again.')),
          );
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error boosting post: $e')),
      );
    } finally {
      if (mounted) setState(() => isProcessing = false);
    }
  }

  double _getBoostPrice(int hours) {
    switch (hours) {
      case 24:
        return 2.99;
      case 72:
        return 7.99;
      case 168:
        return 14.99;
      default:
        return 2.99;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boost Post'),
        centerTitle: true,
        backgroundColor: Colors.teal.shade700,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Boost Duration:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButton<int>(
              value: selectedBoostHours,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 24, child: Text('1 Day – \$2.99')),
                DropdownMenuItem(value: 72, child: Text('3 Days – \$7.99')),
                DropdownMenuItem(value: 168, child: Text('7 Days – \$14.99')),
              ],
              onChanged: (value) =>
                  setState(() => selectedBoostHours = value ?? 24),
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                onPressed: isProcessing ? null : _boostPost,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                  backgroundColor: Colors.teal.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isProcessing
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Boost Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your boosted post will appear at the top of feeds and gain extra visibility.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
