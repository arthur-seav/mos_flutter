import 'package:flutter/material.dart';

import '../../../data/models/order.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// The status pill on an order card (Figma: Order (History)).
///
/// On its way: Latte with Mocha text. Picked up: the success colours.
/// Cancelled or rejected: a soft Danger tint.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      OrderStatus.placed ||
      OrderStatus.confirmed ||
      OrderStatus.preparing ||
      OrderStatus.ready => (AppColors.latte, AppColors.mocha),
      OrderStatus.completed => (AppColors.successBg, AppColors.success),
      OrderStatus.cancelled || OrderStatus.rejected => (
        AppColors.danger.withValues(alpha: 0.12),
        AppColors.danger,
      ),
      _ => (AppColors.muted, AppColors.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: AppTextStyles.label.copyWith(color: foreground),
      ),
    );
  }
}
