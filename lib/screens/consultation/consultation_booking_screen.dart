// lib/screens/consultation/consultation_booking_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:connect_app/theme/tokens.dart';
import '/services/consultation_service.dart';
import '/services/payment_service.dart';

class ConsultationBookingScreen extends StatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final int? ratePerMinute; // dollars

  const ConsultationBookingScreen({
    Key? key,
    required this.targetUserId,
    required this.targetUserName,
    this.ratePerMinute,
  }) : super(key: key);

  @override
  State<ConsultationBookingScreen> createState() => _ConsultationBookingScreenState();
}

class _ConsultationBookingScreenState extends State<ConsultationBookingScreen> {
  final ConsultationService _consultationService = ConsultationService();
  final PaymentService _paymentService = PaymentService();

  // Duration selection
  final List<int> _durationOptions = [15, 30, 45, 60];
  int _selectedDuration = 15;

  // Scheduling
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  // Audio / Video
  String _callType = 'video'; // 'audio' | 'video'

  bool _isProcessing = false;

  // ===== Palette helpers (keeps style consistent) =====
  static const _evergreen = Color(0xFF0F4C46);
  static const _evergreenPressed = Color(0xFF0C3D39);

  // ===== Derived labels / numbers =====
  int get _ratePerMinute => widget.ratePerMinute ?? 0;
  int get _totalCost => _ratePerMinute * _selectedDuration;

  String get _rateLabel => _ratePerMinute > 0 ? '\$$_ratePerMinute / min' : 'Free';
  String get _totalLabel => _ratePerMinute > 0 ? '\$$_totalCost' : 'Free';

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

  // ===== Pickers =====
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.card,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.card,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  // ===== Actions =====
  Future<void> _bookConsultation() async {
    if (_scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date and time.')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to continue.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Charge if needed
      var paid = true;
      if (_totalCost > 0) {
        paid = await _paymentService.processPayment(
          amount: _totalCost.toDouble(),
          userId: currentUser.uid,
        );
      }
      if (!paid) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment failed. Try another card.')),
        );
        return;
      }

      // NOTE: add `callType` to your ConsultationService when you support it.
      await _consultationService.bookConsultation(
        widget.targetUserId,
        _selectedDuration,
        scheduledAt: _scheduledAt!,
        // callType: _callType,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consultation booked successfully.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not book: $e')),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // ===== UI helpers =====
  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
          boxShadow: const [AppShadows.soft],
        ),
        child: child,
      );

  Widget _pill({required Widget child, VoidCallback? onTap}) {
    final c = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.button,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
        child: child,
      ),
    );
    if (onTap == null) return c;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      splashColor: _evergreen.withOpacity(0.12),
      child: c,
    );
  }

  Widget _choicePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final bg = selected ? _evergreen.withOpacity(0.10) : AppColors.button;
    final border = selected ? _evergreen.withOpacity(0.45) : AppColors.border;
    final fg = selected ? _evergreen : AppColors.muted;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: _evergreen.withOpacity(0.12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(fontWeight: FontWeight.w600, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _ctaStyle() {
    return ButtonStyle(
      minimumSize: MaterialStateProperty.all(const Size.fromHeight(52)),
      backgroundColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.disabled)) return _evergreen.withOpacity(0.45);
        if (states.contains(MaterialState.pressed)) return _evergreenPressed;
        return _evergreen;
      }),
      foregroundColor: MaterialStateProperty.all(Colors.white),
      overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.06)),
      shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      elevation: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.pressed)) return 1;
        return 0;
      }),
      shadowColor: MaterialStateProperty.all(Colors.black.withOpacity(0.12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dt = _scheduledAt;
    final scheduledText =
        dt == null ? 'Not set' : DateFormat('EEE, MMM d • h:mm a').format(dt);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        title: const Text('Book a consultation'),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Expert summary
                  _card(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.avatarBg,
                          child:
                              const Icon(Icons.person_outline, color: AppColors.avatarFg),
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
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(_rateLabel,
                                  style: const TextStyle(color: AppColors.muted)),
                            ],
                          ),
                        ),
                        _pill(child: Text('$_selectedDuration min')),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Duration
                  Text('Select duration',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _durationOptions.map((m) {
                      final sel = m == _selectedDuration;
                      return ChoiceChip(
                        label: Text('$m min'),
                        selected: sel,
                        onSelected: (_) => setState(() => _selectedDuration = m),
                        selectedColor: AppColors.button,
                        backgroundColor: AppColors.card,
                        side: const BorderSide(color: AppColors.border),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: sel
                              ? AppColors.text
                              : AppColors.text.withOpacity(0.9),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Call type
                  Text('Call type', style: Theme.of(context).textTheme.titleMedium),
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

                  // Schedule
                  Text('Pick a time', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
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
                                  : DateFormat('MMM d, yyyy').format(_selectedDate!)),
                              const Icon(Icons.calendar_today_outlined,
                                  size: 18, color: AppColors.muted),
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
                                  size: 18, color: AppColors.muted),
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

                  // Cost summary
                  _card(
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long, color: AppColors.muted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Summary',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text)),
                              const SizedBox(height: 6),
                              Text(
                                'Rate: $_rateLabel • Duration: $_selectedDuration min • ${_callType.toUpperCase()}',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _totalLabel,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Sticky bottom CTA
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _bookConsultation,
                  style: _ctaStyle(),
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Book consultation'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
