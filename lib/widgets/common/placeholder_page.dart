import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Temporary body for tabs whose feature has not been built yet.
/// Each tab replaces it with its real screen in a later step.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
    this.children = const [],
  });

  final String title;
  final IconData icon;

  /// Optional extra widgets under the "coming soon" text.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
              Text(title, style: AppTextStyles.title),
              const SizedBox(height: 4),
              const Text(
                'Coming in a later step.',
                style: AppTextStyles.caption,
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}
