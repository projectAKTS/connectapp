// lib/screens/pricing/pricing_screen.dart
import 'package:flutter/material.dart';
import 'package:connect_app/theme/tokens.dart';
import 'pricing_config.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  static const _evergreen = Color(0xFF0F4C46);

  String _callType = 'audio'; // audio | video
  int _selectedDuration = 15;

  double get _price => PricingConfig.getPrice(_selectedDuration, _callType);
  double get _helper => PricingConfig.getHelperPayout(_selectedDuration, _callType);
  double get _platform => PricingConfig.getPlatformFee(_selectedDuration, _callType);

  String _money(double v) => '\$${v.toStringAsFixed(2)} CAD';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Pricing',
          style: TextStyle(
            color: AppColors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _hero(),
          const SizedBox(height: 12),

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Call type',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: -0.2,
                  ),
                ),
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
                        label: 'Video (+30%)',
                        icon: Icons.videocam_outlined,
                        selected: _callType == 'video',
                        onTap: () => setState(() => _callType = 'video'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Select duration',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: PricingConfig.durations.map((m) {
              final sel = m == _selectedDuration;
              return ChoiceChip(
                label: Text(
                  '$m min',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: sel ? _evergreen : AppColors.text,
                  ),
                ),
                selected: sel,
                onSelected: (_) => setState(() => _selectedDuration = m),
                selectedColor: _evergreen.withOpacity(0.10),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: sel ? _evergreen.withOpacity(0.35) : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Price breakdown',
                  style: TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                _row('Total', _money(_price), strong: true),
                const SizedBox(height: 6),
                _row('To helper (80%)', _money(_helper)),
                const SizedBox(height: 6),
                _row('Platform fee (20%)', _money(_platform)),
                const SizedBox(height: 12),
                const Text(
                  'Short calls (5–15 min) are designed to feel easy and repeatable.',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Full table',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 10),

          ...PricingConfig.durations.map((m) {
            final price = PricingConfig.getPrice(m, _callType);
            final helper = PricingConfig.getHelperPayout(m, _callType);

            final isSelected = m == _selectedDuration;
            final accent = isSelected;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _tableRowCard(
                minutes: m,
                price: _money(price),
                helper: _money(helper),
                accent: accent,
                onTap: () => setState(() => _selectedDuration = m),
              ),
            );
          }),

          const SizedBox(height: 8),
          const Text(
            'Prices shown in CAD. Video pricing is set at +30% over audio.',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    final label = _callType == 'video' ? 'Video' : 'Audio';
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
              color: _evergreen.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _evergreen.withOpacity(0.20)),
            ),
            child: const Icon(Icons.payments_outlined, color: _evergreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label consultation pricing',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick a duration to see the final price and earnings.',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
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
              '${_selectedDuration}m',
              style: const TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRowCard({
    required int minutes,
    required String price,
    required String helper,
    required bool accent,
    required VoidCallback onTap,
  }) {
    final border = accent ? _evergreen.withOpacity(0.35) : AppColors.border;
    final bg = accent ? _evergreen.withOpacity(0.06) : Colors.white;

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
                  color: accent ? _evergreen.withOpacity(0.12) : AppColors.button,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: accent ? _evergreen.withOpacity(0.25) : AppColors.border,
                  ),
                ),
                child: Icon(
                  Icons.timer_outlined,
                  color: accent ? _evergreen : AppColors.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$minutes minutes',
                      style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Helper earns $helper',
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
                  color: _evergreen.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _evergreen.withOpacity(0.25)),
                ),
                child: Text(
                  price,
                  style: const TextStyle(
                    color: _evergreen,
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

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: child,
      );

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

  Widget _row(String left, String right, {bool strong = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          left,
          style: TextStyle(
            color: AppColors.text,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
        Text(
          right,
          style: TextStyle(
            color: AppColors.text,
            fontWeight: strong ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
