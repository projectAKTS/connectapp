import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/payment_service.dart';
import '/services/post_service.dart';

class BoostPostScreen extends StatefulWidget {
  final String postId;

  const BoostPostScreen({Key? key, required this.postId}) : super(key: key);

  @override
  _BoostPostScreenState createState() => _BoostPostScreenState();
}

class _BoostPostScreenState extends State<BoostPostScreen> {
  final PaymentService _paymentService = PaymentService();
  final PostService _postService = PostService();

  int selectedBoostHours = 24; // Default boost duration (24 hours)
  bool isProcessing = false;

  Future<void> _boostPost() async {
    setState(() => isProcessing = true);

    // Retrieve the current user's ID from FirebaseAuth.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in.')),
      );
      setState(() => isProcessing = false);
      return;
    }
    final userId = currentUser.uid;

    // Process one-click payment using the stored payment method.
    bool paymentSuccess = await _paymentService.processPayment(
      amount: 2.99, // Example price in dollars
      userId: userId,
    );

    if (paymentSuccess) {
      await _postService.boostPost(widget.postId, selectedBoostHours);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post boosted successfully!')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment failed.')),
      );
    }

    setState(() => isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Boost Post")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "Choose Boost Duration:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            DropdownButton<int>(
              value: selectedBoostHours,
              items: const [
                DropdownMenuItem(value: 24, child: Text("1 Day - \$2.99")),
                DropdownMenuItem(value: 72, child: Text("3 Days - \$7.99")),
                DropdownMenuItem(value: 168, child: Text("7 Days - \$14.99")),
              ],
              onChanged: (value) => setState(() => selectedBoostHours = value!),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: isProcessing ? null : _boostPost,
              child: isProcessing
                  ? const CircularProgressIndicator()
                  : const Text("Boost Now"),
            ),
          ],
        ),
      ),
    );
  }
}
