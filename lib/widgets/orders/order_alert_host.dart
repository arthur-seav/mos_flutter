import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/orders/order_alerts_controller.dart';
import '../../router.dart';
import '../common/top_toast.dart';

/// Shows [OrderAlert]s (FR-16, FR-38) at the top of the screen on every
/// page, with "View" to open the order. Sits above the Navigator in
/// `MaterialApp.router`'s builder.
class OrderAlertHost extends ConsumerWidget {
  const OrderAlertHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(orderAlertsProvider, (_, alert) {
      if (alert == null) return;
      final router = ref.read(routerProvider);
      final overlay = router.routerDelegate.navigatorKey.currentState?.overlay;
      if (overlay == null) return;
      final page = AppRoutes.order(alert.orderId);
      final onIt =
          router.routerDelegate.currentConfiguration.last.matchedLocation ==
          page;
      TopToast.showIn(
        overlay,
        title: alert.title,
        message: alert.message,
        duration: const Duration(seconds: 6),
        // Already on that order's page: nothing to open.
        actionLabel: onIt ? null : 'View',
        onAction: onIt ? null : () => router.push(page),
      );
    });
    return child;
  }
}
