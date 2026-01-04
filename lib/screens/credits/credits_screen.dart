import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:connect_app/services/subscription_service.dart';
import 'package:connect_app/theme/tokens.dart';

class CreditsStoreScreen extends StatefulWidget {
  const CreditsStoreScreen({Key? key}) : super(key: key);

  @override
  State<CreditsStoreScreen> createState() => _CreditsStoreScreenState();
}

class _CreditsStoreScreenState extends State<CreditsStoreScreen> {
  Future<List<ProductDetails>>? _packsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _packsFuture = SubscriptionService.fetchCredits();
    });
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _buy(ProductDetails p) async {
    try {
      await SubscriptionService.buyCredits(p);
      _snack('Purchase started…');
    } catch (e) {
      _snack('Could not start purchase: $e');
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
          appBar: AppBar(title: const Text('Credits')),
          body: const Center(child: Text('Please log in.')),
        ),
      );
    }

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Credits'),
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
                  final minutes = (data['freeConsultationMinutes'] is num)
                      ? (data['freeConsultationMinutes'] as num).toInt()
                      : 0;

                  final empty = minutes <= 0;

                  return _SoftCard(
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.button,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.text),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Your balance',
                                style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$minutes minutes',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                ),
                              ),
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
                            empty ? 'Empty' : 'Available',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
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
                  children: const [
                    Text(
                      'How credits work',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Credits are used for consultations. Your balance increases after a successful purchase.',
                      style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),
              const Text(
                'Buy credit packs',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),

              FutureBuilder<List<ProductDetails>>(
                future: _packsFuture,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return _LoadingPacks();
                  }

                  if (snap.hasError) {
                    return _SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Couldn’t load packs',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _friendlyIapError(snap.error),
                            style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, height: 1.35),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _SmallButton(
                              label: 'Retry',
                              onTap: _reload,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final packs = (snap.data ?? []).toList()
                    ..sort((a, b) => a.rawPrice.compareTo(b.rawPrice));

                  if (packs.isEmpty) {
                    return _SoftCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('No packs found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          SizedBox(height: 6),
                          Text(
                            'Make sure your products exist in App Store Connect and match the IDs in code.',
                            style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: packs.map((p) {
                      final minutes = _minutesFromProductId(p.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SoftCard(
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.primary.withOpacity(0.20)),
                                ),
                                child: const Icon(Icons.timer_outlined, color: AppColors.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      minutes != null ? '$minutes minutes' : p.title,
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      p.description.isNotEmpty ? p.description : 'Use for consultations',
                                      style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              _PrimaryButton(
                                label: p.price,
                                onTap: () => _buy(p),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 18),
              const Text(
                'History',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),

              _SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Coming next',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Optional next step: store a credits ledger (purchases + spends) and show history here.',
                      style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _friendlyIapError(Object? e) {
    final s = e.toString();
    // Keep it user-friendly + short, but still helpful for you.
    if (s.contains('storekit_no_response')) {
      return 'StoreKit didn’t respond. Check Apple ID / Sandbox login, In-App Purchase capability, and App Store Connect product setup. Then retry.';
    }
    return s;
  }

  static int? _minutesFromProductId(String id) {
    // Your IDs: credits_5min, credits_30min, credits_60min
    if (id.contains('5min')) return 5;
    if (id.contains('30min')) return 30;
    if (id.contains('60min')) return 60;
    return null;
  }
}

// ---------------- UI bits ----------------

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

class _LoadingPacks extends StatelessWidget {
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
