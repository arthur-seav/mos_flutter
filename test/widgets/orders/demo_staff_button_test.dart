import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/orders/order_tracking_controller.dart';
import 'package:mos_app/data/mock/demo_staff.dart';
import 'package:mos_app/data/mock/mock_backend.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/models/order.dart';
import 'package:mos_app/widgets/orders/demo_staff_button.dart';

import '../../helpers.dart';

void main() {
  late MockBackend backend;
  late int orderId;

  Future<void> pumpButton(WidgetTester tester, {bool withMock = true}) async {
    backend = testBackend();
    backend.auth.signedInUserId = 1;
    await tester.runAsync(() async {
      final o = await backend.orders.createOrder(
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
      await backend.orders.payWithCard(orderId: o.id, cardId: cards.first.id);
      orderId = o.id;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...backend.overrides,
          trackingPollProvider.overrideWithValue(null),
        ],
        // A real backend has no mock staff (inner scope overrides it).
        child: ProviderScope(
          overrides: [if (!withMock) demoStaffProvider.overrideWithValue(null)],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  final s = ref.watch(orderTrackingProvider(orderId)).value;
                  return s == null
                      ? const SizedBox.shrink()
                      : Column(
                          children: [
                            Text(s.progress.title),
                            DemoStaffButton(order: s.order),
                          ],
                        );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('moves the order on, step by step, and the page follows', (
    tester,
  ) async {
    await pumpButton(tester);
    expect(find.text('Order placed'), findsOneWidget);

    await tester.tap(find.text('Demo: staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm order'));
    await tester.pumpAndSettle();
    expect(find.text('Order confirmed'), findsOneWidget);

    await tester.tap(find.text('Demo: staff'));
    await tester.pumpAndSettle();
    expect(find.text('Reject: Sold out'), findsNothing); // only while Placed
    await tester.tap(find.text('Start preparing'));
    await tester.pumpAndSettle();
    expect(find.text('Being prepared'), findsOneWidget);
  });

  testWidgets('TC-27: reject with "Sold out"', (tester) async {
    await pumpButton(tester);
    await tester.tap(find.text('Demo: staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject: Sold out'));
    await tester.pumpAndSettle();
    expect(find.text('Order rejected'), findsOneWidget);
    // An order that is over has no staff button.
    expect(find.text('Demo: staff'), findsNothing);
  });

  testWidgets('the automatic staff switch pauses them', (tester) async {
    await pumpButton(tester);
    await tester.tap(find.text('Demo: staff'));
    await tester.pumpAndSettle();
    expect(backend.orders.staffPaused, isFalse);
    await tester.tap(find.text('Automatic staff'));
    await tester.pump();
    expect(backend.orders.staffPaused, isTrue);
  });

  testWidgets('not shown with a real backend', (tester) async {
    await pumpButton(tester, withMock: false);
    expect(find.text('Order placed'), findsOneWidget);
    expect(find.text('Demo: staff'), findsNothing);
  });
}
