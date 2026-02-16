import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
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
  static const bool _showTestPlan = true;

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

  Future<void> _activateTestPremium() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final expires = DateTime.now().add(const Duration(days: 30));
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'premiumStatus': 'active',
      'premiumExpiresAt': Timestamp.fromDate(expires),
      'discountPercent': 10,
      'premiumPlan': 'test_free',
      'premiumRole': 'seeker',
    }, SetOptions(merge: true));
    _snack('Test Premium enabled for 30 days.');
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
    final sectionTitle =
        textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800);
    final muted = textTheme.bodyMedium?.copyWith(
      color: AppColors.muted,
      fontWeight: FontWeight.w600,
    );
    final headline = textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.text,
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _PremiumHero(
              title: 'Upgrade to Premium',
              subtitle:
                  'Get 1 free 5‑minute audio monthly plus 10% off every consultation.',
            ),
            const SizedBox(height: 14),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (ctx, snap) {
                final data = snap.data?.data() ?? const <String, dynamic>{};
                final statusRaw = (data['premiumStatus'] ?? 'Free').toString().trim();
                final status = (statusRaw.isEmpty || statusRaw == 'none') ? 'Free' : statusRaw;
                final expiresAt = data['premiumExpiresAt'];
                DateTime? expires;
                if (expiresAt is Timestamp) expires = expiresAt.toDate();

                final active = status != 'Free' &&
                    (expires == null || expires.isAfter(DateTime.now()));

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
                            Text(active ? 'Active' : 'Free',
                                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            if (active && expires != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Ends: ${DateFormat.yMMMd().format(expires)}',
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

            const SizedBox(height: 14),

            _SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What’s included', style: sectionTitle),
                  const SizedBox(height: 10),
                  const _BenefitRow(text: '1 free 5‑minute audio each month'),
                  const _BenefitRow(text: '10% off every consultation'),
                  const _BenefitRow(text: 'Premium badge on your profile'),
                ],
              ),
            ),

            const SizedBox(height: 18),
            Text('Plans', style: headline),
            const SizedBox(height: 10),

            if (_showTestPlan || kDebugMode) ...[
              _SoftCard(
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
                      child: const Icon(Icons.bolt, color: AppColors.text),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Test plan', style: sectionTitle),
                          const SizedBox(height: 4),
                          Text('30‑day access for testing only.', style: muted),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$0.00',
                          style: textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        _PrimaryButton(
                          label: 'Activate',
                          onTap: _activateTestPremium,
                          compact: true,
                          minWidth: 108,
                        ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            FutureBuilder<List<ProductDetails>>(
              future: _subsFuture,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return _LoadingPlans();
                }
                if (snap.hasError) {
                  final err = snap.error.toString();
                  final storekitHint = err.contains('storekit_no_response')
                      ? 'Plans are unavailable on this device. Try again on a real device and ensure products are active in App Store Connect.'
                      : 'Plans are temporarily unavailable.';
                  return _SoftCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Plans unavailable', style: sectionTitle),
                        const SizedBox(height: 6),
                        Text(
                          storekitHint,
                          style: muted?.copyWith(height: 1.35),
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
                        Text('Restore purchases',
                            style: sectionTitle?.copyWith(fontSize: 16)),
                        const SizedBox(height: 2),
                        Text(
                          'Use this if you’ve already subscribed on this Apple ID.',
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
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.primary.withOpacity(0.20)),
            ),
            child:
                const Icon(Icons.check_rounded, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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

class _PremiumHero extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PremiumHero({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.card,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.soft],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: const Icon(Icons.workspace_premium_outlined,
                color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  subtitle,
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
  final bool compact;
  final double? minWidth;
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.compact = false,
    this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 34 : 40,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          minimumSize: Size(minWidth ?? 0, compact ? 34 : 40),
          padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
          textStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: compact ? 12 : 15,
          ),
          visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
