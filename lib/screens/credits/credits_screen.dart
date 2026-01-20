// lib/screens/credits/credits_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:connect_app/services/subscription_service.dart';
import 'package:connect_app/theme/tokens.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
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
      final list = await SubscriptionService.fetchCredits();
      list.sort((a, b) => _minutesFromId(a.id).compareTo(_minutesFromId(b.id)));

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

  int _minutesFromId(String id) {
    final s = id.toLowerCase();
    if (s.contains('5')) return 5;
    if (s.contains('30')) return 30;
    if (s.contains('60')) return 60;
    final digits = RegExp(r'\d+').firstMatch(s)?.group(0);
    return int.tryParse(digits ?? '') ?? 5;
    }

  String _badgeFor(int minutes) {
    if (minutes >= 60) return 'Best value';
    if (minutes >= 30) return 'Popular';
    return 'Quick';
  }

  Future<void> _buy(ProductDetails p) async {
    try {
      await SubscriptionService.buyCredits(p);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase started…')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn’t start purchase: $e')),
      );
    }
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
          'Credits',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.text),
          ),
        ],
      ),
      body: uid == null
          ? const Center(child: Text('Please log in'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data();
                final minutes = (data?['freeConsultationMinutes'] as num?)?.toInt() ?? 0;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _BalanceCard(minutes: minutes),
                    const SizedBox(height: 14),

                    const Text(
                      'Top up',
                      style: TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (_loading) const _LoadingCard(label: 'Loading…'),
                    if (!_loading && _error != null) _ErrorCard(error: _error!, onRetry: _load),
                    if (!_loading && _error == null && _products.isEmpty)
                      const _EmptyCard(
                        title: 'No options found',
                        body: 'Make sure your credit products exist in App Store Connect.',
                      ),

                    if (!_loading && _error == null && _products.isNotEmpty) ...[
                      ..._products.map((p) {
                        final m = _minutesFromId(p.id);
                        final accent = m >= 60;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _OptionCard(
                            title: '$m minutes',
                            badge: _badgeFor(m),
                            price: p.price,
                            accent: accent,
                            onTap: () => _buy(p),
                          ),
                        );
                      }),
                    ],

                    const SizedBox(height: 8),
                    const Text(
                      'Credits are used automatically when you book a call.',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final int minutes;
  const _BalanceCard({required this.minutes});

  @override
  Widget build(BuildContext context) {
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
            child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your balance',
                  style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '$minutes minutes',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final String title;
  final String badge;
  final String price;
  final bool accent;
  final VoidCallback onTap;

  const _OptionCard({
    required this.title,
    required this.badge,
    required this.price,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = accent ? AppColors.primary.withOpacity(0.35) : AppColors.border;
    final bg = accent ? AppColors.primary.withOpacity(0.06) : AppColors.card;

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
                  accent ? Icons.bolt_rounded : Icons.add_circle_rounded,
                  color: accent ? AppColors.primary : AppColors.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.button,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 12),
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
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------- shared UI cards ----------

class _LoadingCard extends StatelessWidget {
  final String label;
  const _LoadingCard({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
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
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Couldn’t load', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 15)),
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
        color: AppColors.card,
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
