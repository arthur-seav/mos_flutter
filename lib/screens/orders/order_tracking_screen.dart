import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_routes.dart';
import '../../controllers/orders/order_progress.dart';
import '../../controllers/orders/order_tracking_controller.dart';
import '../../controllers/orders/reorder.dart';
import '../../data/models/order.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/square_icon_button.dart';
import '../../widgets/common/top_toast.dart';
import '../../widgets/orders/demo_staff_button.dart';
import '../../widgets/orders/tracking/cancel_order_sheet.dart';
import '../../widgets/orders/tracking/order_summary_row.dart';
import '../../widgets/orders/tracking/pickup_code_card.dart';
import '../../widgets/orders/tracking/progress_timeline.dart';
import '../../widgets/orders/tracking/tracking_status_card.dart';

/// SA 2.0 §4.2.4 Order Tracking (FR-15 to FR-17, TC-24 to TC-28).
///
/// Shows where one order is: the status card, the pickup code (or the
/// refund once it ended early), the five steps, what was ordered, and
/// the one thing the customer can do now — cancel it, reorder it, or go
/// back to the menu. Everything it shows comes from [OrderProgress]; the
/// page only draws it.
class OrderTrackingScreen extends ConsumerWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(orderTrackingProvider(orderId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              orderId: orderId,
              pickupCode: tracking.value?.order.pickupCode,
            ),
            Expanded(
              child: tracking.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.espresso),
                ),
                error: (error, stackTrace) => Center(
                  child: SingleChildScrollView(
                    child: EmptyState(
                      icon: Icons.wifi_off,
                      title: "We couldn't load this order",
                      message: 'Check your connection and try again.',
                      action: FilledButton(
                        onPressed: () =>
                            ref.invalidate(orderTrackingProvider(orderId)),
                        child: const Text('Try again'),
                      ),
                    ),
                  ),
                ),
                data: (state) => _TrackingBody(orderId: orderId, state: state),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Close button and "Order #A1024".
class _Header extends StatelessWidget {
  const _Header({required this.orderId, required this.pickupCode});

  final int orderId;
  final String? pickupCode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          SquareIconButton(
            icon: Icons.close,
            tooltip: 'Close',
            // Opened from the payment result there is nothing to go back
            // to, so the Orders tab is the way out.
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.orders),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Order #${pickupCode ?? orderId}',
              style: AppTextStyles.title,
            ),
          ),
        ],
      ),
    );
  }
}

/// The scrolling part plus whatever the customer can do at the bottom.
class _TrackingBody extends StatelessWidget {
  const _TrackingBody({required this.orderId, required this.state});

  final int orderId;
  final TrackingState state;

  @override
  Widget build(BuildContext context) {
    final order = state.order;
    final progress = state.progress;
    final refund = state.refund;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TrackingStatusCard(status: order.status, progress: progress),
                const SizedBox(height: 16),
                if (refund != null)
                  RefundCard(refund: refund)
                else
                  PickupCodeCard(
                    code: order.pickupCode ?? '—',
                    hint: progress.pickupHint,
                    isReady: order.status == OrderStatus.ready,
                  ),
                const SizedBox(height: 16),
                ProgressTimeline(steps: progress.steps),
                const SizedBox(height: 16),
                OrderSummaryRow(order: order, summary: progress.summary),
                // Mock backend only: lets a demo play the staff's part.
                DemoStaffButton(order: order),
              ],
            ),
          ),
        ),
        _BottomActions(orderId: orderId, order: order),
      ],
    );
  }
}

/// Cancel while it is still Placed (BR-09), reorder once it is done
/// (TC-28), or back to the menu once it ended early. While the store is
/// making the drinks there is nothing to do.
class _BottomActions extends ConsumerWidget {
  const _BottomActions({required this.orderId, required this.order});

  final int orderId;
  final Order order;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final outcome = await showCancelOrderSheet(
      context,
      orderId: orderId,
      refundAmount: order.totalAmount.format(),
      method: order.paidPayment?.method,
    );
    final message = outcome?.message;
    // TC-26: the store confirmed first, so it was not cancelled.
    if (message == null || !context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), persist: false));
  }

  Future<void> _reorder(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(reorderProvider)(order);
    if (!context.mounted) return;
    TopToast.show(context, title: result.message);
    if (result.added > 0) context.push(AppRoutes.cart);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Widget> children;
    if (order.canCancel) {
      final where =
          'to ${(order.paidPayment?.method ?? PaymentMethod.khqr).refundAccount}';
      children = [
        Text(
          'You can cancel until the store confirms. Refunds go back '
          '$where.',
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => _cancel(context, ref),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger),
          ),
          child: const Text('Cancel order'),
        ),
      ];
    } else if (order.status == OrderStatus.completed) {
      children = [
        FilledButton(
          onPressed: () => _reorder(context, ref),
          child: const Text('Reorder'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => context.go(AppRoutes.home),
          child: const Text('Back to home'),
        ),
      ];
    } else if (order.endedEarly) {
      children = [
        FilledButton(
          onPressed: () => context.go(AppRoutes.menu),
          child: const Text('Back to menu'),
        ),
      ];
    } else {
      // Confirmed, preparing or ready: the customer just waits.
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
