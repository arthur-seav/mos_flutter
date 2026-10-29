import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// A white card with an icon, a title, a subtitle and a radio mark: one
/// pickup time or payment method on the checkout page (Figma: Checkout).
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  /// False = faded and not tappable (e.g. ASAP while the store is closed).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      enabled: enabled,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: selected ? AppColors.espresso : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.muted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: AppColors.mocha),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTextStyles.bodyMedium),
                        const SizedBox(height: 2),
                        Text(subtitle, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _RadioMark(selected: selected),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.espresso : AppColors.border,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.espresso,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
