import 'dart:async';

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order.dart';
import '../../data/repository_providers.dart';
import '../account/notification_settings_controller.dart';
import '../auth/auth_controller.dart';

/// A notice for the customer: their order is ready (FR-16) or the store
/// rejected it (FR-38).
@immutable
class OrderAlert {
  const OrderAlert({
    required this.orderId,
    required this.title,
    required this.message,
  });

  final int orderId;
  final String title;
  final String message;

  static OrderAlert? forChange(Order order) {
    final code = order.pickupCode ?? '${order.id}';
    return switch (order.status) {
      OrderStatus.ready => OrderAlert(
        orderId: order.id,
        title: 'Order #$code is ready',
        message: 'Show your pickup code at the counter.',
      ),
      OrderStatus.rejected => OrderAlert(
        orderId: order.id,
        title: 'Order #$code was rejected',
        message:
            'Reason: ${order.rejectReason ?? 'not given'}. '
                    '${order.paidPayment?.isRefund ?? false ? 'Your refund is on its way.' : ''}'
                .trim(),
      ),
      _ => null,
    };
  }
}

/// How often the app checks a signed-in customer's orders for changes.
/// A real backend would push notifications instead (FCM); tests set this
/// to null and call [OrderAlertsController.poll].
final orderAlertsPollProvider = Provider<Duration?>(
  (ref) => const Duration(seconds: 3),
);

/// Watches the signed-in customer's orders and gives an [OrderAlert] when
/// one becomes Ready or Rejected, wherever the customer is in the app.
/// The first look only notes each order's status, so old news is not
/// announced again.
final orderAlertsProvider =
    NotifierProvider<OrderAlertsController, OrderAlert?>(
      OrderAlertsController.new,
    );

class OrderAlertsController extends Notifier<OrderAlert?> {
  final _seen = <int, OrderStatus>{};
  bool _hasLooked = false;
  bool _busy = false;
  Timer? _timer;

  @override
  OrderAlert? build() {
    final signedIn = ref.watch(
      authControllerProvider.select((a) => a.isCustomer),
    );
    _seen.clear();
    _hasLooked = false;
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());
    if (signedIn) {
      final every = ref.read(orderAlertsPollProvider);
      if (every != null) _timer = Timer.periodic(every, (_) => poll());
      Future.microtask(poll);
    }
    return null;
  }

  /// The profile page's "Notifications" switch.
  Future<bool> _wanted() async {
    try {
      return await ref.read(notificationsEnabledProvider.future);
    } on Object {
      return true;
    }
  }

  Future<void> poll() async {
    if (_busy || !ref.read(authControllerProvider).isCustomer) return;
    _busy = true;
    try {
      final orders = await ref.read(orderRepositoryProvider).fetchMyOrders();
      if (!ref.mounted) return;
      for (final order in orders) {
        final before = _seen[order.id];
        _seen[order.id] = order.status;
        if (!_hasLooked || before == order.status) continue;
        final alert = OrderAlert.forChange(order);
        if (alert != null && await _wanted()) state = alert;
      }
      _hasLooked = true;
    } on Object {
      // Try again next time.
    } finally {
      _busy = false;
    }
  }
}
