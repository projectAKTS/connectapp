import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:intl/intl.dart';
import 'package:connect_app/theme/tokens.dart';
import '/services/consultation_service.dart';
import '/services/payment_service.dart';
import 'package:connect_app/screens/pricing/pricing_config.dart';
import '/services/interaction_service.dart';
import 'package:connect_app/widgets/full_screen_back_gesture.dart';

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
  final PaymentService _paymentService = PaymentService();

  final List<int> _durationOptions = PricingConfig.durations;
  int _selectedDuration = 15;
  String _callType = 'audio';

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isProcessing = false;

  static const _evergreen = Color(0xFF0F4C46);

  User? _user;
  late final StreamSubscription<User?> _authSub;
  StreamSubscription<DocumentSnapshot>? _userDocSub;

  bool _premiumActive = false;
  String _userRole = 'seeker';
  DateTime? _premiumExpiresAt;
  DateTime? _freeAudioUsedAt;

  static const int _premiumDiscountPercent = 10;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
      if (!mounted) return;
      setState(() => _user = u);
      if (u != null) _listenUserDoc(u.uid);
    });
    if (_user != null) {
      _listenUserDoc(_user!.uid);
    }
  }

  @override
  void dispose() {
    _authSub.cancel();
    _userDocSub?.cancel();
    super.dispose();
  }

  void _listenUserDoc(String uid) {
    _userDocSub?.cancel();
    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      _applyUserBenefits(data);
    });
  }

  DateTime? _tsToDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    return null;
  }

  bool _isPremiumActive(Map<String, dynamic> data) {
    final status = (data['premiumStatus'] ?? '').toString().toLowerCase();
    if (status.isEmpty || status == 'none') return false;
    final exp = _tsToDate(data['premiumExpiresAt']);
    if (exp != null && exp.isBefore(DateTime.now())) return false;
    return true;
  }

  void _applyUserBenefits(Map<String, dynamic> data) {
    final role = (data['role'] ?? 'seeker').toString();
    final active = _isPremiumActive(data);
    final exp = _tsToDate(data['premiumExpiresAt']);
    final freeUsedAt = _tsToDate(data['premiumFreeAudioUsedAt']);
    if (!mounted) return;
    setState(() {
      _userRole = role;
      _premiumActive = active;
      _premiumExpiresAt = exp;
      _freeAudioUsedAt = freeUsedAt;
    });
  }

  String get _availabilityLabel {
    final simulatedHours = 2;
    if (simulatedHours <= 1) return 'Usually responds within an hour';
    if (simulatedHours <= 3) return 'Usually responds within 2 hours';
    if (simulatedHours <= 6) return 'Usually responds today';
    return 'Usually responds within a day';
  }

  bool get _isSeeker => _userRole != 'helper';
  bool get _isSeekerPremium => _premiumActive && _isSeeker;

  bool get _freeAudioUsedThisMonth {
    final used = _freeAudioUsedAt;
    if (used == null) return false;
    final now = DateTime.now();
    return used.year == now.year && used.month == now.month;
  }

  bool get _freeAudioEligible {
    return _isSeekerPremium &&
        _callType == 'audio' &&
        _selectedDuration == 5 &&
        !_freeAudioUsedThisMonth;
  }

  double get _basePrice => PricingConfig.getPrice(_selectedDuration, _callType);
  double get _finalPrice {
    if (_freeAudioEligible) return 0.0;
    if (_isSeekerPremium) {
      final discounted = _basePrice * (1 - (_premiumDiscountPercent / 100));
      return double.parse(discounted.toStringAsFixed(2));
    }
    return _basePrice;
  }

  double get _payout =>
      PricingConfig.getHelperPayout(_selectedDuration, _callType);
  String get _priceLabel => '\$${_finalPrice.toStringAsFixed(2)} CAD';
  String get _basePriceLabel => '\$${_basePrice.toStringAsFixed(2)} CAD';
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _bookConsultation() async {
    debugPrint('🟢 [Booking] Start booking flow for ${widget.targetUserName}');
    debugPrint(
        '💰 Selected duration: $_selectedDuration min | Type: $_callType | Price: $_finalPrice');

    if (_scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date and time.')),
      );
      return;
    }

    User? user = _user ?? FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        debugPrint('🟡 [Booking] Waiting for user auth state...');
        user = await FirebaseAuth.instance.authStateChanges().firstWhere(
          (u) => u != null,
          orElse: () => null,
        );
      } catch (e) {
        debugPrint('❌ [Booking] Auth state error: $e');
      }
    }

    if (user == null) {
      debugPrint('❌ [Booking] No authenticated user found.');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to continue.')),
      );
      return;
    }

    debugPrint('👤 [Booking] Current user: ${user.uid}');
    if (!mounted) return;
    setState(() => _isProcessing = true);

    final rootNav = Navigator.of(context, rootNavigator: true);

    try {
      debugPrint('🔑 [Booking] Refreshing Firebase ID token...');
      await user.getIdToken(true);
      debugPrint('🔒 [Booking] Refreshing Firebase App Check token...');
      final appCheckToken = await FirebaseAppCheck.instance.getToken(true);
      debugPrint('🧾 [Booking] App Check token: ${appCheckToken?.substring(0, 12)}...');

      debugPrint('💳 [Booking] Ensuring Stripe customer exists...');
      await _paymentService.ensureStripeCustomer();

      var charge = const PaymentChargeResult(result: PaymentResult.failed);
      if (_finalPrice > 0) {
        debugPrint('🧾 [Booking] Starting payment flow. Amount: $_finalPrice CAD');
        var charge = await _paymentService.processPayment(amount: _finalPrice);
        debugPrint('📤 [Booking] processPayment() returned: ${charge.result}');

        if (charge.result == PaymentResult.unauthenticated) {
          debugPrint('🔁 [Booking] Retrying payment after refreshing tokens...');
          await user.getIdToken(true);
          await FirebaseAppCheck.instance.getToken(true);
          charge = await _paymentService.processPayment(amount: _finalPrice);
          debugPrint('📤 [Booking] Retry result: ${charge.result}');
        }

        switch (charge.result) {
          case PaymentResult.needsSetup:
            debugPrint('⚠️ [Booking] User needs to add a card.');
            final go = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Add a card to continue'),
                content: const Text(
                    'You don’t have a saved payment method yet. Add one now to complete the booking.'),
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
              // ✅ Global route -> ROOT
              await rootNav.pushNamed('/paymentSetup');
            }
            if (mounted) setState(() => _isProcessing = false);
            return;

          case PaymentResult.unauthenticated:
            debugPrint('❌ [Booking] Payment failed — unauthenticated.');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Session expired. Please sign in again.')),
              );
              setState(() => _isProcessing = false);
            }
            return;

          case PaymentResult.failed:
            debugPrint('❌ [Booking] Payment failed at Stripe layer.');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Payment failed. Please try again.')),
              );
              setState(() => _isProcessing = false);
            }
            return;

          case PaymentResult.success:
            debugPrint('✅ [Booking] Payment succeeded!');
            break;
        }
      } else {
        debugPrint('🟢 [Booking] Price is 0 — skipping payment step.');
      }

      debugPrint('🗓️ [Booking] Saving consultation in Firestore...');
      await _consultationService.bookConsultation(
        widget.targetUserId,
        _selectedDuration,
        scheduledAt: _scheduledAt!,
        costOverride: _finalPrice,
        paymentIntentId: _finalPrice > 0 ? charge.paymentIntentId : null,
        currency: 'cad',
      );

      if (_freeAudioEligible) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(
          {'premiumFreeAudioUsedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      }

      await InteractionService.recordInteraction(widget.targetUserId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultation booked successfully.')),
      );
      debugPrint('✅ [Booking] Consultation booked successfully!');
      Navigator.pop(context);
    } catch (e, st) {
      debugPrint('❌ [Booking] Exception caught: $e');
      debugPrint('🪵 Stack trace:\n$st');

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not book: $e')));
      }
    } finally {
      debugPrint('🏁 [Booking] Flow finished.');
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dt = _scheduledAt;
    final scheduledText =
        dt == null ? 'Not set' : DateFormat('EEE, MMM d • h:mm a').format(dt);

    return FullScreenBackGesture(
      child: Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Book a Consultation'),
        backgroundColor: AppColors.canvas,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
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
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    size: 13,
                                    color: AppColors.muted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _availabilityLabel,
                                    style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _pill(child: Text('$_selectedDuration min')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Select duration',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _durationOptions.map((m) {
                      final sel = m == _selectedDuration;
                      return ChoiceChip(
                        label: Text(
                          '$m min',
                          style: TextStyle(
                            color: sel
                                ? Colors.black
                                : AppColors.text.withOpacity(0.8),
                          ),
                        ),
                        selected: sel,
                        onSelected: (_) => setState(() => _selectedDuration = m),
                        selectedColor: Colors.white,
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: sel
                              ? Colors.black
                              : AppColors.border.withOpacity(0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text('Call type',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 20),
                  Text('Pick a time',
                      style: Theme.of(context).textTheme.titleMedium),
                  Row(
                    children: [
                      Expanded(
                        child: _pill(
                          onTap: _pickDate,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_selectedDate == null
                                  ? 'Pick date'
                                  : DateFormat('MMM d, yyyy')
                                      .format(_selectedDate!)),
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
                              Text(_selectedTime == null
                                  ? 'Pick time'
                                  : _selectedTime!.format(context)),
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
                      style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 20),
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Summary',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.text)),
                        const SizedBox(height: 6),
                        Text(
                          'Type: ${_callType.toUpperCase()} • Duration: $_selectedDuration min',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        const SizedBox(height: 6),
                        if (_isSeekerPremium && !_freeAudioEligible)
                          Row(
                            children: [
                              Text(
                                _basePriceLabel,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '-$_premiumDiscountPercent%',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        if (_freeAudioEligible)
                          const Text(
                            'Premium: 5 min free audio applied',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        Text('Total: $_priceLabel',
                            style: const TextStyle(color: AppColors.text)),
                        Text(_payoutLabel,
                            style: const TextStyle(color: AppColors.muted)),
                      ],
                    ),
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
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _bookConsultation,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: _evergreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('Book consultation ($_priceLabel)'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );

  Widget _pill({required Widget child, VoidCallback? onTap}) {
    final c = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
    if (onTap == null) return c;
    return InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(14), child: c);
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
          color: selected ? _evergreen.withOpacity(0.1) : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fg.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: TextStyle(fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
  }
}
