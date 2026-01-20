// lib/screens/premium/premium_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:connect_app/services/subscription_service.dart';
import 'package:connect_app/theme/tokens.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _loading = true;
  String? _error;
  List<ProductDetails> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await SubscriptionService.fetchSubscriptions();

      int rank(ProductDetails p) {
        final id = p.id.toLowerCase();
        if (id.contains('yearly') || id.contains('annual')) return 0;
        if (id.contains('monthly')) return 1;
        return 9;
      }

      list.sort((a, b) => rank(a).compareTo(rank(b)));

      setState(() {
        _products = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _buy(ProductDetails p) async {
    try {
      await SubscriptionService.buySubscription(p);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription started…')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t start subscription: $e')),
      );
    }
  }

  Future<void> _restore() async {
    try {
      await SubscriptionService.restore();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restoring purchases…')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    }
  }

  bool _isActive(String status, DateTime? expiresAt) {
    if (status.trim().isEmpty || status.toLowerCase() == 'free') return false;
    if (expiresAt == null) return false;
    return expiresAt.isAfter(DateTime.now());
  }

  int _discountPercent(Map<String, dynamic>? data) {
    final v = (data?['premiumDiscountPercent'] ?? data?['discountPercent']);
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Premium',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton(
            onPressed: _restore,
            child: const Text(
              'Restore',
              style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Please log in'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data();
                final status = (data?['premiumStatus'] as String?) ?? 'Free';
                final expiresAt = (data?['premiumExpiresAt'] as Timestamp?)?.toDate();
                final active = _isActive(status, expiresAt);
                final discount = _discountPercent(data);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _HeroCard(
                      active: active,
                      status: status,
                      expiresAt: expiresAt,
                      discountPercent: discount,
                    ),
                    const SizedBox(height: 12),

                    const _SimpleBenefitsCard(),
                    const SizedBox(height: 16),

                    const Text(
                      'Choose a plan',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (_loading) const _LoadingCard(label: 'Loading plans…'),
                    if (!_loading && _error != null) _ErrorCard(error: _error!, onRetry: _load),
                    if (!_loading && _error == null && _products.isEmpty)
                      const _EmptyCard(
                        title: 'No plans found',
                        body: 'The store didn’t return any subscription products. Check your product IDs and store setup.',
                      ),

                    if (!_loading && _error == null && _products.isNotEmpty) ...[
                      ..._buildPlanCards(_products),
                    ],

                    const SizedBox(height: 14),
                    const _FinePrint(),
                  ],
                );
              },
            ),
    );
  }

  List<Widget> _buildPlanCards(List<ProductDetails> products) {
    ProductDetails? yearly;
    ProductDetails? monthly;

    for (final p in products) {
      final id = p.id.toLowerCase();
      if (id.contains('yearly') || id.contains('annual')) yearly ??= p;
      if (id.contains('monthly')) monthly ??= p;
    }

    final out = <Widget>[];

    if (yearly != null) {
      out.add(
        _PlanCard(
          title: 'Yearly',
          badge: 'Best value',
          subtitle: 'Save more over the year',
          price: yearly.price,
          accent: true,
          onTap: () => _buy(yearly!),
        ),
      );
      out.add(const SizedBox(height: 10));
    }

    if (monthly != null) {
      out.add(
        _PlanCard(
          title: 'Monthly',
          badge: 'Flexible',
          subtitle: 'Cancel anytime (per store policy)',
          price: monthly.price,
          accent: false,
          onTap: () => _buy(monthly!),
        ),
      );
      out.add(const SizedBox(height: 10));
    }

    // fallback for any extra products
    for (final p in products) {
      if (p == yearly || p == monthly) continue;
      out.add(
        _PlanCard(
          title: p.title.isNotEmpty ? p.title : 'Premium',
          badge: 'Plan',
          subtitle: p.description.isNotEmpty ? p.description : 'Premium subscription',
          price: p.price,
          accent: false,
          onTap: () => _buy(p),
        ),
      );
      out.add(const SizedBox(height: 10));
    }

    return out;
  }
}

class _HeroCard extends StatelessWidget {
  final bool active;
  final String status;
  final DateTime? expiresAt;
  final int discountPercent;

  const _HeroCard({
    required this.active,
    required this.status,
    required this.expiresAt,
    required this.discountPercent,
  });

  String _dateLabel(DateTime? d) {
    if (d == null) return 'No expiry date';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    final label = active ? 'Active' : 'Not active';
    final detail = active ? 'Renews/ends on ${_dateLabel(expiresAt)}' : 'Upgrade to unlock Premium';
    final discountLine = (discountPercent > 0) ? '$discountPercent% consultation discount' : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.20)),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'You’re Premium' : 'Premium',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  active ? 'Plan: $status • $detail' : detail,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                if (discountLine != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    discountLine,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.button,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              label,
              style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleBenefitsCard extends StatelessWidget {
  const _SimpleBenefitsCard();

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.button,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, color: AppColors.text, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What you get',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          row(Icons.trending_up_rounded, 'Priority visibility on your posts'),
          row(Icons.block_rounded, 'Ad-free experience'),
          row(Icons.star_rounded, 'Access to Premium posts'),
          row(Icons.local_offer_rounded, 'Consultation discounts applied at booking'),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String badge;
  final String subtitle;
  final String price;
  final bool accent;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.badge,
    required this.subtitle,
    required this.price,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = accent ? AppColors.primary.withOpacity(0.35) : AppColors.border;
    final bg = accent ? AppColors.primary.withOpacity(0.06) : Colors.white;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent ? AppColors.primary.withOpacity(0.12) : AppColors.button,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accent ? AppColors.primary.withOpacity(0.25) : AppColors.border,
                  ),
                ),
                child: Icon(
                  accent ? Icons.auto_awesome_rounded : Icons.star_rounded,
                  color: accent ? AppColors.primary : AppColors.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.button,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                ),
                child: Text(
                  price,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final String label;
  const _LoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Couldn’t load plans', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 15)),
          const SizedBox(height: 6),
          Text(error, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, height: 1.25)),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.button,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Retry', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String body;
  const _EmptyCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, height: 1.25)),
        ],
      ),
    );
  }
}

class _FinePrint extends StatelessWidget {
  const _FinePrint();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Subscriptions are billed through Apple. You can manage or cancel anytime in your Apple ID subscription settings.',
      style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, height: 1.25),
    );
  }
}
