import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// A centred icon, title and message for "nothing here" and "could not
/// load" states (no search results, empty cart, empty order history...).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Optional button, e.g. "Try again".
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.latte,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 36, color: AppColors.mocha),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
