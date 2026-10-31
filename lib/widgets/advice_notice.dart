import 'package:connect_app/models/help_topics.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:flutter/material.dart';

/// "Personal experience, not professional advice" — shown wherever people
/// look for or book help.
class AdviceNotice extends StatelessWidget {
  const AdviceNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.button,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.muted),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              HelpTopics.adviceNotice,
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
