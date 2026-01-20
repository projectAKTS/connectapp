import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:connect_app/theme/tokens.dart';

class SettingsScreen extends StatelessWidget {
  SettingsScreen({super.key});

  void _nav(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        children: [
          const _SectionTitle('Payments'),
          _SettingTile(
            icon: Icons.credit_card_rounded,
            title: 'Payment method',
            subtitle: 'Manage your card for consultations & purchases',
            onTap: () => _nav(context, '/paymentSetup'),
          ),
          const SizedBox(height: 12),

          const _SectionTitle('Purchases'),
          _SettingTile(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Credits',
            subtitle: 'Buy minutes for consultations',
            onTap: () => _nav(context, '/credits'),
          ),
          _SettingTile(
            icon: Icons.workspace_premium_rounded,
            title: 'Premium',
            subtitle: 'Plans, perks, and restore',
            onTap: () => _nav(context, '/premium'),
          ),
          const SizedBox(height: 12),

          const _SectionTitle('Account'),
          _SettingTile(
            icon: Icons.logout_rounded,
            title: 'Sign out',
            subtitle: 'Log out from this device',
            destructive: true,
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = destructive ? const Color(0xFFD84A4A) : AppColors.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.button,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(icon, color: AppColors.muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: titleColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.border),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
