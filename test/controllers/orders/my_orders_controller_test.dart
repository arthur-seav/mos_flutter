import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/orders/my_orders_controller.dart';
import 'package:mos_app/controllers/orders/order_tracking_controller.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/data/mock/mock_backend.dart';
import 'package:mos_app/data/models/order.dart';

import '../../helpers.dart';

void main() {
  test('FR-18: in progress and past, newest first', () async {
    final backend = MockBackend(
      latency: Duration.zero,
      clock: testNow,
      seedHistory: true,
    );
    backend.auth.signedInUserId = MockAuthRepository.daraId;
    final container = ProviderContainer.test(
      overrides: [
        ...backend.overrides,
        trackingPollProvider.overrideWithValue(null),
      ],
    );
    final sub = container.listen(myOrdersProvider, (_, _) {});
    addTearDown(sub.close);

    var mine = await container.read(myOrdersProvider.future);
    expect(mine.inProgress, isEmpty);
    expect(mine.past.map((o) => o.pickupCode), ['A1019', 'A1007', 'A0998']);

    // A new paid order is in progress until it is picked up.
    final order = await backend.orders.createOrder(
      const OrderRequest(
        lines: [OrderLineRequest(productId: 1, optionIds: [], quantity: 1)],
        pickupType: PickupType.asap,
      ),
    );
    final cards = await backend.cards.fetchCards();
    await backend.orders.payWithCard(orderId: order.id, cardId: cards.first.id);
    await container.read(myOrdersProvider.notifier).refresh();
    mine = container.read(myOrdersProvider).requireValue;
    expect(mine.inProgress.map((o) => o.pickupCode), ['A1024']);
    expect(mine.past, hasLength(3));
    expect(mine.isEmpty, isFalse);
  });

  test('no orders yet: empty', () async {
    final backend = MockBackend(latency: Duration.zero, clock: testNow);
    backend.auth.signedInUserId = MockAuthRepository.daraId;
    final container = ProviderContainer.test(overrides: backend.overrides);
    final sub = container.listen(myOrdersProvider, (_, _) {});
    addTearDown(sub.close);
    expect((await container.read(myOrdersProvider.future)).isEmpty, isTrue);
  });
}
