import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/orders/order_tracking_controller.dart';
import '../../../data/models/order.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// What came back from the cancel sheet. [message] is null when the
/// order really was cancelled; a sentence means the store confirmed it
/// first (TC-26), and the page shows that sentence.
@immutable
class CancelOutcome {
  const CancelOutcome(this.message);

  final String? message;
}

/// Where a refund goes: "to your card" for a card, "to your KHQR
/// account" otherwise. Used by the sheet and the line above the button.
String refundDestination(PaymentMethod? method) => method == PaymentMethod.card
    ? 'to your card'
    : 'to your ${(method ?? PaymentMethod.khqr).label} account';

/// "Cancel this order?" (Figma: overlay-cancel_order, BR-09, TC-25).
///
/// Returns null if the customer kept the order, or a [CancelOutcome]
/// once the cancel went through the backend.
Future<CancelOutcome?> showCancelOrderSheet(
  BuildContext context, {
  required int orderId,
  required String refundAmount,
  required PaymentMethod? method,
}) {
  return showModalBottomSheet<CancelOutcome>(
    context: context,
    backgroundColor: AppColors.canvas,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _CancelOrderSheet(
      orderId: orderId,
      refundAmount: refundAmount,
      method: method,
    ),
  );
}

class _CancelOrderSheet extends ConsumerWidget {
  const _CancelOrderSheet({
    required this.orderId,
    required this.refundAmount,
    required this.method,
  });

  final int orderId;
  final String refundAmount;
  final PaymentMethod? method;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCancelling = ref.watch(
      orderTrackingProvider(
        orderId,
      ).select((s) => s.value?.isCancelling ?? false),
    );

    Future<void> confirm() async {
      final message = await ref
          .read(orderTrackingProvider(orderId).notifier)
          .cancel();
      if (context.mounted) Navigator.of(context).pop(CancelOutcome(message));
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 30,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cancel this order?',
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "The store hasn't started on it yet. You'll get a full refund "
              'of $refundAmount ${refundDestination(method)}.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isCancelling ? null : confirm,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: AppColors.onBrand,
                ),
                child: isCancelling
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.onBrand,
                        ),
                      )
                    : const Text('Yes, cancel order'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: isCancelling
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Keep my order'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
