// lib/screens/consultation/consultation_booking_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/screens/pricing/pricing_config.dart';

import '/services/consultation_service.dart';
import '/services/payment_service.dart';
import '/services/interaction_service.dart';

class ConsultationBookingScreen extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;

  const ConsultationBookingScreen({
    Key? key,
    required this.targetUserId,
    required this.targetUserName,
  }) : super(key: key);

  @override
  State<ConsultationBookingScreen> createState() =>
      _ConsultationBookingScreenState();
}

class _ConsultationBookingScreenState extends State<ConsultationBookingScreen> {
  final ConsultationService _consultationService = ConsultationService();

  // ✅ FIX: PaymentService is a singleton (PaymentService.instance)
  final PaymentService _paymentService = PaymentService.instance;

  final List<int> _durationOptions = PricingConfig.durations;
  int _selectedDuration = 15;
  String _callType = 'audio';

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _isProcessing = false;

  User? _user;
  late final StreamSubscription<User?> _authSub;

  static const _evergreen = Color(0xFF0F4C46);

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (mounted) setState(() => _user = u);
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  // --- labels/prices ---------------------------------------------------------

  String get _availabilityLabel {
    // TODO: replace with real helper availability later
    const simulatedHours = 2;
    if (simulatedHours <= 1) return 'Usually responds within an hour';
    if (simulatedHours <= 3) return 'Usually responds within 2 hours';
    if (simulatedHours <= 6) return 'Usually responds today';
    return 'Usually responds within a day';
  }

  double get _price => PricingConfig.getPrice(_selectedDuration, _callType);
  double get _payout => PricingConfig.getHelperPayout(_selectedDuration, _callType);

  String get _priceLabel => '\$${_price.toStringAsFixed(2)} CAD';
  String get _payoutLabel => '\$${_payout.toStringAsFixed(2)} to helper';

  DateTime? get _scheduledAt {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  // --- pickers ---------------------------------------------------------------

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && mounted) setState(() => _selectedTime = picked);
  }

  // --- helpers ---------------------------------------------------------------

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<User?> _requireUser() async {
    final u = _user ?? FirebaseAuth.instance.currentUser;
    if (u != null) return u;

    try {
      return await FirebaseAuth.instance
          .authStateChanges()
          .firstWhere((x) => x != null, orElse: () => null);
    } catch (_) {
      return null;
    }
  }

  // ✅ Premium discount helpers (minimal)
  bool _premiumActiveFrom(Map<String, dynamic>? data) {
    final status = (data?['premiumStatus'] as String?) ?? 'Free';
    final expiresAt = (data?['premiumExpiresAt'] as Timestamp?)?.toDate();
    if (status.trim().isEmpty || status.toLowerCase() == 'free') return false;
    if (expiresAt == null) return false;
    return expiresAt.isAfter(DateTime.now());
  }

  int _premiumDiscountPercentFrom(Map<String, dynamic>? data) {
    final v = (data?['premiumDiscountPercent'] ?? data?['discountPercent']);
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 0;
  }

  double _applyDiscount(double amount, int percent) {
    if (percent <= 0) return amount;
    final d = (amount * percent) / 100.0;
    final out = amount - d;
    return out < 0 ? 0 : out;
  }

  String _money(double v) => '\$${v.toStringAsFixed(2)} CAD';

  // --- booking flow ----------------------------------------------------------

  Future<void> _bookConsultation() async {
    if (_isProcessing) return;

    final scheduled = _scheduledAt;
    if (scheduled == null) {
      _toast('Please pick a date and time.');
      return;
    }

    final user = await _requireUser();
    if (user == null) {
      _toast('Please sign in to continue.');
      return;
    }

    if (!mounted) return;
    setState(() => _isProcessing = true);

    // Use ROOT navigator for global routes (so tab navigator doesn’t trap it)
    final rootNav = Navigator.of(context, rootNavigator: true);

    try {
      // ✅ Fetch premium status once for payment amount
      double amountToCharge = _price;
      try {
        final uSnap = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        final data = uSnap.data();
        final isPremium = _premiumActiveFrom(data);
        final pct = isPremium ? _premiumDiscountPercentFrom(data) : 0;
        amountToCharge = _applyDiscount(_price, pct);
      } catch (_) {
        // If anything fails, fall back to normal price
        amountToCharge = _price;
      }

      // (1) Payment (if needed)
      if (amountToCharge > 0) {
        // ensure customer exists (PaymentService handles tokens/appcheck inside)
        final okCustomer = await _paymentService.ensureStripeCustomer();
        if (!okCustomer) {
          _toast('Please sign in again and retry.');
          return;
        }

        var result = await _paymentService.processPayment(amount: amountToCharge);

        // If unauthenticated, try 1 retry (token refresh) then stop.
        if (result == PaymentResult.unauthenticated) {
          await user.getIdToken(true);
          result = await _paymentService.processPayment(amount: amountToCharge);
        }

        switch (result) {
          case PaymentResult.success:
            // continue
            break;

          case PaymentResult.needsSetup:
            final go = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Add a card to continue'),
                content: const Text(
                  'You don’t have a saved payment method yet. Add one now to complete the booking.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Add Card'),
                  ),
                ],
              ),
            );

            if (go == true) {
              await rootNav.pushNamed('/paymentSetup');
            }
            return;

          case PaymentResult.blocked:
            _toast('Payments temporarily unavailable (App Check). Try again later.');
            return;

          case PaymentResult.unauthenticated:
            _toast('Session expired. Please sign in again.');
            return;

          case PaymentResult.failed:
            _toast('Payment failed. Please try again.');
            return;
        }
      }

      // (2) Save consultation
      await _consultationService.bookConsultation(
        widget.targetUserId,
        _selectedDuration,
        scheduledAt: scheduled,
      );

      // (3) Interaction tracking
      await InteractionService.recordInteraction(widget.targetUserId);

      if (!mounted) return;
      _toast('Consultation booked successfully.');
      Navigator.pop(context);
    } catch (e) {
      _toast('Could not book: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // --- UI --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final dt = _scheduledAt;
    final scheduledText =
        dt == null ? 'Not set' : DateFormat('EEE, MMM d • h:mm a').format(dt);

    final uid = _user?.uid;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Book a Consultation'),
        backgroundColor: AppColors.canvas,
        elevation: 0,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _card(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.avatarBg,
                          child: const Icon(
                            Icons.person_outline,
                            color: AppColors.avatarFg,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.targetUserName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.text,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.schedule,
                                      size: 13, color: AppColors.muted),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _availabilityLabel,
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _pill(
                          child: Text(
                            '$_selectedDuration min',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text('Select duration',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _durationOptions.map((m) {
                      final sel = m == _selectedDuration;
                      return ChoiceChip(
                        label: Text(
                          '$m min',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: sel ? _evergreen : AppColors.text,
                          ),
                        ),
                        selected: sel,
                        onSelected: (_) => setState(() => _selectedDuration = m),
                        selectedColor: _evergreen.withOpacity(0.10),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: sel
                              ? _evergreen.withOpacity(0.35)
                              : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  Text('Call type',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _choicePill(
                          label: 'Audio',
                          icon: Icons.call_outlined,
                          selected: _callType == 'audio',
                          onTap: () => setState(() => _callType = 'audio'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _choicePill(
                          label: 'Video',
                          icon: Icons.videocam_outlined,
                          selected: _callType == 'video',
                          onTap: () => setState(() => _callType = 'video'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text('Pick a time',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _pill(
                          onTap: _pickDate,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedDate == null
                                    ? 'Pick date'
                                    : DateFormat('MMM d, yyyy')
                                        .format(_selectedDate!),
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Icon(Icons.calendar_today_outlined,
                                  color: AppColors.muted, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _pill(
                          onTap: _pickTime,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedTime == null
                                    ? 'Pick time'
                                    : _selectedTime!.format(context),
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Icon(Icons.schedule,
                                  color: AppColors.muted, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Text('Scheduled: $scheduledText',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      )),

                  const SizedBox(height: 18),

                  // ✅ Summary with Premium discount (no other UI changes)
                  if (uid == null)
                    _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Summary',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.text,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Type: ${_callType.toUpperCase()} • Duration: $_selectedDuration min',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total',
                                style: TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                _priceLabel,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _payoutLabel,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                      builder: (context, snap) {
                        final data = snap.data?.data();
                        final isPremium = _premiumActiveFrom(data);
                        final pct = isPremium ? _premiumDiscountPercentFrom(data) : 0;

                        final subtotal = _price;
                        final total = _applyDiscount(subtotal, pct);
                        final discountAmount = subtotal - total;

                        return _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Summary',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.text,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Type: ${_callType.toUpperCase()} • Duration: $_selectedDuration min',
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 10),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Subtotal',
                                    style: TextStyle(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    _money(subtotal),
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),

                              if (isPremium && pct > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Premium −$pct%',
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '-${_money(discountAmount)}',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total',
                                    style: TextStyle(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    _money(total),
                                    style: const TextStyle(
                                      color: AppColors.text,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),
                              Text(
                                _payoutLabel,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),

            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: (uid == null)
                      ? null
                      : FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                  builder: (context, snap) {
                    final data = snap.data?.data();
                    final isPremium = _premiumActiveFrom(data);
                    final pct = isPremium ? _premiumDiscountPercentFrom(data) : 0;

                    final total = _applyDiscount(_price, pct);
                    final buttonLabel = 'Book consultation (${_money(total)})';

                    return ElevatedButton(
                      onPressed: _isProcessing ? null : _bookConsultation,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: _evergreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              buttonLabel,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI helpers ------------------------------------------------------------

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );

  Widget _pill({required Widget child, VoidCallback? onTap}) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );

    if (onTap == null) return content;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: content,
    );
  }

  Widget _choicePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final fg = selected ? _evergreen : AppColors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _evergreen.withOpacity(0.10) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _evergreen.withOpacity(0.35) : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
