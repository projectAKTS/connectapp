import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:connect_app/services/subscription_service.dart';
import 'package:connect_app/theme/tokens.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({Key? key}) : super(key: key);

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  Future<List<ProductDetails>>? _subsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _subsFuture = SubscriptionService.fetchSubscriptions();
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _buy(ProductDetails p) async {
    try {
      await SubscriptionService.buySubscription(p);
      _snack('Purchase started…');
    } catch (e) {
      _snack('Could not start purchase: $e');
    }
  }

  Future<void> _restore() async {
    try {
      await InAppPurchase.instance.restorePurchases();
      _snack('Restore requested…');
    } catch (e) {
      _snack('Restore failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final theme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: AppColors.canvas,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        foregroundColor: AppColors.text,
        iconTheme: IconThemeData(color: AppColors.text),
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    if (uid == null) {
      return Theme(
        data: theme,
        child: Scaffold(
          appBar: AppBar(title: const Text('Premium')),
          body: const Center(child: Text('Please log in.')),
        ),
      );
    }

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Premium'),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _reload,
            ),
          ],
        ),
        body: RefreshIndicator.adaptive(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                builder: (ctx, snap) {
                  final data = snap.data?.data() ?? const <String, dynamic>{};
                  final status = (data['premiumStatus'] ?? 'Free').toString();
                  final expiresAt = data['premiumExpiresAt'];
                  DateTime? expires;
                  if (expiresAt is Timestamp) expires = expiresAt.toDate();

                  final active = status != 'Free' && (expires == null || expires.isAfter(DateTime.now()));

                  return _SoftCard(
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.primary.withOpacity(0.20)),
                          ),
                          child: const Icon(Icons.workspace_premium_outlined, color: AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current plan',
                                style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                active ? status : 'Free',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                              ),
                              if (active && expires != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Renews/ends: ${DateFormat.yMMMd().format(expires)}',
                                  style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
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
                            active ? 'Active' : 'Free',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              _SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('What you get', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    SizedBox(height: 10),
                    _BenefitRow(text: 'Priority visibility for your posts'),
                    _BenefitRow(text: 'Premium badge on profile'),
                    _BenefitRow(text: 'More boosts / perks (future)'),
                    _BenefitRow(text: 'Early access to new features'),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Text(
                'Choose a plan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),

              FutureBuilder<List<ProductDetails>>(
                future: _subsFuture,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return _LoadingPlans();
                  }
                  if (snap.hasError) {
                    return _SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Couldn’t load plans',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(
                            snap.error.toString(),
                            style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, height: 1.35),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _SmallButton(label: 'Retry', onTap: _reload),
                          ),
                        ],
                      ),
                    );
                  }

                  final plans = (snap.data ?? []).toList()
                    ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

                  if (plans.isEmpty) {
                    return _SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('No plans found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          SizedBox(height: 6),
                          Text(
                            'Make sure premium_monthly and premium_yearly exist in App Store Connect.',
                            style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: plans.map((p) {
                      final isYearly = p.id.contains('year');
                      final title = isYearly ? 'Yearly' : 'Monthly';
                      final subtitle = isYearly ? 'Best value' : 'Cancel anytime';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SoftCard(
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.button,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Icon(
                                  isYearly ? Icons.calendar_month_outlined : Icons.date_range_outlined,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Text(subtitle,
                                        style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              _PrimaryButton(label: p.price, onTap: () => _buy(p)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 12),
              _SoftCard(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Already purchased?',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    _SmallButton(label: 'Restore', onTap: _restore),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String text;
  const _BenefitRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.primary.withOpacity(0.20)),
            ),
            child: const Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftCard extends StatelessWidget {
  final Widget child;
  const _SoftCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.soft],
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
        child: Text(label),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SmallButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.button,
          foregroundColor: AppColors.text,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
        child: Text(label),
      ),
    );
  }
}

class _LoadingPlans extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget line(double w) => Container(
          width: w,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.button,
            borderRadius: BorderRadius.circular(99),
          ),
        );

    return _SoftCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.button,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                line(120),
                const SizedBox(height: 10),
                line(180),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 72,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.button,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
          ),
        ],
      ),
    );
  }
}
