import 'package:flutter/material.dart';

import '../../../controllers/orders/order_progress.dart';
import '../../../data/models/order.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// The "Current status" card at the top of the tracking page (Figma:
/// Order · Placed … Order · Cancelled). Its colour follows
/// [OrderProgress.tone] and the five bars follow
/// [OrderProgress.filledSegments].
class TrackingStatusCard extends StatelessWidget {
  const TrackingStatusCard({
    super.key,
    required this.status,
    required this.progress,
  });

  final OrderStatus status;
  final OrderProgress progress;

  /// Figma: dark brown while it is being made, green when ready, lighter
  /// brown once picked up, red when it ended early.
  static Color backgroundOf(StatusTone tone) => switch (tone) {
    StatusTone.inProgress => AppColors.espresso,
    StatusTone.ready => AppColors.success,
    StatusTone.done => AppColors.mocha,
    StatusTone.ended => AppColors.danger,
  };

  static IconData iconOf(OrderStatus status) => switch (status) {
    OrderStatus.placed => Icons.receipt_long,
    OrderStatus.confirmed => Icons.check,
    OrderStatus.preparing => Icons.coffee,
    OrderStatus.ready => Icons.shopping_bag,
    OrderStatus.completed => Icons.star_outline,
    OrderStatus.cancelled ||
    OrderStatus.rejected ||
    OrderStatus.abandoned ||
    OrderStatus.pendingPayment => Icons.close,
  };

  @override
  Widget build(BuildContext context) {
    final background = backgroundOf(progress.tone);
    // Caramel reads as "lit" on the dark brown card; on green, brown and
    // red the lit bars are the card's own cream text colour.
    final litBar = progress.tone == StatusTone.inProgress
        ? AppColors.caramel
        : AppColors.onBrand;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.onBrand,
                  shape: BoxShape.circle,
                ),
                child: Icon(iconOf(status), size: 26, color: background),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current status',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.onBrand.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      progress.title,
                      style: AppTextStyles.title.copyWith(
                        color: AppColors.onBrand,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      progress.subtitle,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.onBrand,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < OrderProgress.stepCount; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < progress.filledSegments
                          ? litBar
                          : AppColors.onBrand.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
