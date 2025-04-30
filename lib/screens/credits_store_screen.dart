// lib/screens/credits_store_screen.dart
import 'package:flutter/material.dart';
import '/services/subscription_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class CreditsStoreScreen extends StatefulWidget {
  const CreditsStoreScreen({Key? key}) : super(key: key);
  @override
  _CreditsStoreScreenState createState() => _CreditsStoreScreenState();
}

class _CreditsStoreScreenState extends State<CreditsStoreScreen> {
  List<ProductDetails> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    SubscriptionService.setupListener(_onPurchaseUpdates);
  }

  Future<void> _loadProducts() async {
    final prods = await SubscriptionService.fetchCredits();
    setState(() {
      _products = prods;
      _loading = false;
    });
  }

  void _onPurchaseUpdates(List<PurchaseDetails> details) {
    // handled in main.dart listener
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy Consultation Credits')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _products.map((p) {
                return Card(
                  child: ListTile(
                    title: Text(p.title),
                    subtitle: Text(p.description),
                    trailing: ElevatedButton(
                      onPressed: () => SubscriptionService.buyCredits(p),
                      child: Text(p.price),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
