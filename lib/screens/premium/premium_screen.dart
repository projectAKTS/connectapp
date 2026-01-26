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
      _subsFuture = _loadPlans();
    });
  }

  Future<List<ProductDetails>> _loadPlans() async {
    final available = await SubscriptionService.init();
    if (!available) {
      throw Exception('In-app purchases are not available on this device.');
    }
    return SubscriptionService.fetchSubscriptions();
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
    final textTheme = Theme.of(context).textTheme;
    final sectionTitle = textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
    final muted = textTheme.bodyMedium?.copyWith(
      color: AppColors.muted,
      fontWeight: FontWeight.w600,
    );

    if (uid == null) {
      return Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(title: const Text('Premium')),
        body: const Center(child: Text('Please log in.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
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
            _HeroCard(),
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (ctx, snap) {
                final data = snap.data?.data() ?? const <String, dynamic>{};
                final statusRaw = (data['premiumStatus'] ?? 'Free').toString().trim();
                final status = (statusRaw.isEmpty || statusRaw == 'none') ? 'Free' : statusRaw;
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
                            Text('Current plan', style: muted),
                            const SizedBox(height: 4),
                            Text(active ? status : 'Free',
                                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            if (active && expires != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Renews/ends: ${DateFormat.yMMMd().format(expires)}',
                                style: muted,
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
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                          ),
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
                children: [
                  Text('What you get', style: sectionTitle),
                  const SizedBox(height: 10),
                  const _BenefitRow(text: 'Priority visibility for your posts'),
                  const _BenefitRow(text: 'Premium badge on profile'),
                  const _BenefitRow(text: 'More boosts / perks (future)'),
                  const _BenefitRow(text: 'Early access to new features'),
                ],
              ),
            ),

            const SizedBox(height: 18),
            Text('Choose a plan', style: sectionTitle?.copyWith(fontSize: 20)),
            const SizedBox(height: 10),

            FutureBuilder<List<ProductDetails>>(
              future: _subsFuture,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return _LoadingPlans();
                }
                if (snap.hasError) {
                  final err = snap.error.toString();
                  final storekitHint = err.contains('storekit_no_response')
                      ? 'StoreKit did not respond. Try again on a real device and ensure the products are active in App Store Connect.'
                      : null;
                  return _SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Couldn’t load plans', style: sectionTitle),
                        const SizedBox(height: 6),
                        Text(
                          err,
                          style: muted?.copyWith(height: 1.35),
                        ),
                        if (storekitHint != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            storekitHint,
                            style: muted?.copyWith(height: 1.35),
                          ),
                        ],
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
                      children: [
                        Text('No plans found', style: sectionTitle),
                        const SizedBox(height: 6),
                        Text(
                          'Make sure premium_monthly and premium_yearly exist in App Store Connect.',
                          style: muted,
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
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
                                      isYearly
                                          ? Icons.calendar_month_outlined
                                          : Icons.date_range_outlined,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title,
                                            style:
                                                textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 4),
                                        Text(subtitle, style: muted),
                                      ],
                                    ),
                                  ),
                                  if (isYearly)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.button,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Text(
                                        'Save 20%',
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: AppColors.text,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.price,
                                      style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                  _PrimaryButton(label: 'Select', onTap: () => _buy(p)),
                                ],
                              ),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Already purchased?',
                            style: sectionTitle?.copyWith(fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          'Restore purchases made on this Apple ID.',
                          style: muted,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _SmallButton(label: 'Restore', onTap: _restore),
                ],
              ),
            ),
          ],
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
    final textTheme = Theme.of(context).textTheme;
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
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.10),
            AppColors.button.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.soft],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: const Icon(Icons.workspace_premium_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Premium',
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Get priority visibility and premium features tailored to your profile.',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.text),
                ),
              ],
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
      height: 36,
      child: TextButton(
        onPressed: onTap,
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
