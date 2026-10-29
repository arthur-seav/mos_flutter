import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/account/notification_settings_controller.dart';
import 'package:mos_app/controllers/auth/auth_controller.dart';
import 'package:mos_app/controllers/orders/order_alerts_controller.dart';
import 'package:mos_app/controllers/orders/order_tracking_controller.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/data/mock/mock_backend.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/models/order.dart';
import 'package:mos_app/data/repositories/settings_repository.dart';

import '../../helpers.dart';

void main() {
  late DateTime now;
  late MockBackend backend;
  late ProviderContainer container;

  setUp(() async {
    now = testNow();
    backend = MockBackend(latency: Duration.zero, clock: () => now);
    container = ProviderContainer.test(
      overrides: [
        ...backend.overrides,
        trackingPollProvider.overrideWithValue(null),
        orderAlertsPollProvider.overrideWithValue(null),
        settingsRepositoryProvider.overrideWithValue(
          InMemorySettingsRepository(),
        ),
      ],
    );
    await container
        .read(authControllerProvider.notifier)
        .signIn(
          identifier: 'dara@example.com',
          password: MockAuthRepository.demoPassword,
        );
  });

  Future<Order> paidOrder() async {
    final order = await backend.orders.createOrder(
      const OrderRequest(
        lines: [
          OrderLineRequest(
            productId: 18,
            optionIds: [
              MockMenuRepository.medium,
              MockMenuRepository.hot,
              MockMenuRepository.normalSugar,
            ],
            quantity: 1,
          ),
        ],
        pickupType: PickupType.asap,
      ),
    );
    final cards = await backend.cards.fetchCards();
    await backend.orders.payWithCard(orderId: order.id, cardId: cards.first.id);
    return order;
  }

  group('tracking', () {
    test('TC-24: refresh picks up what the staff did', () async {
      final o = await paidOrder();
      final p = orderTrackingProvider(o.id);
      final sub = container.listen(p, (_, _) {});
      addTearDown(sub.close);
      expect((await container.read(p.future)).order.status, OrderStatus.placed);
      expect(container.read(p).requireValue.asapPrepMin, 10);

      backend.orders.staffAdvance(o.id);
      await container.read(p.notifier).refresh();
      expect(
        container.read(p).requireValue.order.status,
        OrderStatus.confirmed,
      );
      expect(container.read(p).requireValue.progress.title, 'Order confirmed');
    });

    test('TC-25: cancel while Placed', () async {
      final o = await paidOrder();
      final p = orderTrackingProvider(o.id);
      final sub = container.listen(p, (_, _) {});
      addTearDown(sub.close);
      await container.read(p.future);

      expect(await container.read(p.notifier).cancel(), isNull);
      final s = container.read(p).requireValue;
      expect(s.order.status, OrderStatus.cancelled);
      expect(s.refund!.amount, r'$3.50');
      expect(s.isCancelling, isFalse);
    });

    test(
      'TC-26: the store confirmed first -> message, page shows it',
      () async {
        final o = await paidOrder();
        final p = orderTrackingProvider(o.id);
        final sub = container.listen(p, (_, _) {});
        addTearDown(sub.close);
        await container.read(p.future);
        backend.orders.staffAdvance(o.id); // page still says Placed

        expect(
          await container.read(p.notifier).cancel(),
          'The store has already confirmed this order, so it can no longer '
          'be cancelled.',
        );
        final s = container.read(p).requireValue;
        expect(s.order.status, OrderStatus.confirmed);
        expect(s.order.canCancel, isFalse);
      },
    );
  });

  group('alerts (FR-16, FR-38)', () {
    test('the first look announces nothing; Ready then does', () async {
      final o = await paidOrder();
      final alerts = container.listen(orderAlertsProvider, (_, _) {});
      addTearDown(alerts.close);
      await container.read(orderAlertsProvider.notifier).poll();
      expect(container.read(orderAlertsProvider), isNull);

      backend.orders.staffAdvance(o.id); // confirmed: no alert
      await container.read(orderAlertsProvider.notifier).poll();
      expect(container.read(orderAlertsProvider), isNull);

      backend.orders
        ..staffAdvance(o.id)
        ..staffAdvance(o.id); // ready
      await container.read(orderAlertsProvider.notifier).poll();
      final alert = container.read(orderAlertsProvider)!;
      expect(alert.orderId, o.id);
      expect(alert.title, 'Order #A1024 is ready');
      expect(alert.message, 'Show your pickup code at the counter.');
    });

    test('TC-27: a rejected order is announced with the reason', () async {
      final o = await paidOrder();
      final alerts = container.listen(orderAlertsProvider, (_, _) {});
      addTearDown(alerts.close);
      await container.read(orderAlertsProvider.notifier).poll();

      backend.orders.staffReject(o.id, 'Sold out');
      await container.read(orderAlertsProvider.notifier).poll();
      final alert = container.read(orderAlertsProvider)!;
      expect(alert.title, 'Order #A1024 was rejected');
      expect(alert.message, 'Reason: Sold out. Your refund is on its way.');
    });

    test(
      'an order that is already ready when first seen is old news',
      () async {
        final o = await paidOrder();
        backend.orders
          ..staffAdvance(o.id)
          ..staffAdvance(o.id)
          ..staffAdvance(o.id);
        final alerts = container.listen(orderAlertsProvider, (_, _) {});
        addTearDown(alerts.close);
        await container.read(orderAlertsProvider.notifier).poll();
        expect(container.read(orderAlertsProvider), isNull);
      },
    );

    test('guests are not watched', () async {
      await container.read(authControllerProvider.notifier).signOut();
      container.read(authControllerProvider.notifier).continueAsGuest();
      final alerts = container.listen(orderAlertsProvider, (_, _) {});
      addTearDown(alerts.close);
      await container.read(orderAlertsProvider.notifier).poll();
      expect(container.read(orderAlertsProvider), isNull);
    });

    test('the Notifications switch off: no notice', () async {
      final o = await paidOrder();
      await container.read(notificationsEnabledProvider.notifier).set(false);
      final alerts = container.listen(orderAlertsProvider, (_, _) {});
      addTearDown(alerts.close);
      await container.read(orderAlertsProvider.notifier).poll();
      backend.orders
        ..staffAdvance(o.id)
        ..staffAdvance(o.id)
        ..staffAdvance(o.id);
      await container.read(orderAlertsProvider.notifier).poll();
      expect(container.read(orderAlertsProvider), isNull);
    });
  });
}
