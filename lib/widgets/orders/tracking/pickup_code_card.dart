import 'package:flutter/material.dart';

import '../../../controllers/orders/order_progress.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// The pickup code and what to do with it (Figma: the card under the
/// status card). It turns latte-coloured once the drinks are waiting.
class PickupCodeCard extends StatelessWidget {
  const PickupCodeCard({
    super.key,
    required this.code,
    required this.hint,
    required this.isReady,
  });

  final String code;

  /// [OrderProgress.pickupHint].
  final String hint;

  /// Status is Ready: the card is highlighted.
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isReady ? AppColors.latte : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pickup code', style: AppTextStyles.caption),
              const SizedBox(height: 2),
              Text(code, style: AppTextStyles.pageTitle),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(hint, style: AppTextStyles.caption),
            ),
          ),
        ],
      ),
    );
  }
}

/// Replaces [PickupCodeCard] on a cancelled or rejected order that was
/// paid for (SA §4.2.4.6, BR-10): how much is going back and where.
class RefundCard extends StatelessWidget {
  const RefundCard({super.key, required this.refund});

  final RefundInfo refund;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.muted,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.currency_exchange,
              size: 20,
              color: AppColors.mocha,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Refund \u00b7 ${refund.amount}',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(refund.where, style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: refund.isDone ? AppColors.successBg : AppColors.muted,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              refund.isDone ? 'Refunded' : 'Processing',
              style: AppTextStyles.caption.copyWith(
                color: refund.isDone ? AppColors.success : AppColors.mocha,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
