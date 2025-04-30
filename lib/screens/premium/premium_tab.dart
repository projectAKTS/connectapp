// lib/screens/premium/premium_tab.dart
import 'package:flutter/material.dart';
import '/services/subscription_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class PremiumTab extends StatefulWidget {
  const PremiumTab({Key? key}) : super(key: key);
  @override
  _PremiumTabState createState() => _PremiumTabState();
}

class _PremiumTabState extends State<PremiumTab> {
  List<ProductDetails> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    SubscriptionService.setupListener(_onPurchaseUpdates);
  }

  Future<void> _loadProducts() async {
    final prods = await SubscriptionService.fetchSubscriptions();
    setState(() {
      _products = prods;
      _loading = false;
    });
  }

  void _onPurchaseUpdates(List<PurchaseDetails> details) {
    // actual handling occurs in main.dart listener
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Go Premium')),
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
                      onPressed: () => SubscriptionService.buySubscription(p),
                      child: Text(p.price),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
