import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/checkout/qr_saver.dart';
import 'package:mos_app/data/mock/mock_backend.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/models/order.dart';
import 'package:mos_app/router.dart';
import 'package:mos_app/screens/cart/cart_screen.dart';
import 'package:mos_app/screens/checkout/payment_result_screen.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../helpers.dart';

class _FakeQrSaver implements QrSaver {
  final calls = <String>[];
  bool throws = false;

  @override
  Future<void> save(KhqrCharge charge, Order order) async {
    if (throws) throw const GalExceptionStub();
    calls.add(QrSaver.fileName(order));
  }
}

/// Minimal stand-in: the real GalException needs a platform exception.
class GalExceptionStub implements Exception {
  const GalExceptionStub();
}

void main() {
  Future<Order> createOrder(MockBackend backend) async {
    return backend.orders.createOrder(
      const OrderRequest(
        lines: [
          OrderLineRequest(
            productId: 18,
            optionIds: [
              MockMenuRepository.medium,
              MockMenuRepository.hot,
              MockMenuRepository.normalSugar,
            ],
            quantity: 2,
          ),
        ],
        pickupType: PickupType.asap,
      ),
    );
  }

  testWidgets('shows merchant, amount, countdown and QR code', (tester) async {
    var now = testNow();
    final b = testBackend(clock: () => now);
    final c = await pumpMosApp(tester, backend: b);
    await signInAsDara(tester);

    late Order order;
    await tester.runAsync(() async {
      order = await createOrder(b);
    });

    c.read(routerProvider).push(AppRoutes.khqr(order.id));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('MOS Coffee'), findsOneWidget);
    expect(find.text('\$7.00'), findsOneWidget);
    expect(find.text('Expires in 05:00'), findsOneWidget);
    expect(find.byType(PrettyQrView), findsOneWidget);
    expect(find.text('KHQR'), findsOneWidget);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Expires in 04:59'), findsOneWidget);
  });

  testWidgets('TC-21: paid within expiry goes to result and clears cart', (
    tester,
  ) async {
    var now = testNow();
    final b = testBackend(clock: () => now);
    final c = await pumpMosApp(tester, backend: b);
    await signInAsDara(tester);

    late Order order;
    await tester.runAsync(() async {
      order = await createOrder(b);
    });

    c.read(routerProvider).push(AppRoutes.khqr(order.id));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Paid 5s after the charge starts; the controller only polls on even
    // ticks, so the 6s poll is the first one to see it.
    for (var i = 0; i < 5; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.byType(PaymentResultScreen), findsNothing); // not yet
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(PaymentResultScreen), findsOneWidget);
    final result = tester.widget<PaymentResultScreen>(
      find.byType(PaymentResultScreen),
    );
    expect(result.outcome.isPaid, isTrue);
    expect(result.outcome.order.pickupCode, 'A1024'); // FR-14
  });

  testWidgets('expired charge (never pays) goes to failed result', (
    tester,
  ) async {
    var now = testNow();
    final b = testBackend(clock: () => now, khqrPaysAfter: null);
    final c = await pumpMosApp(tester, backend: b);
    await signInAsDara(tester);

    late Order order;
    await tester.runAsync(() async {
      order = await createOrder(b);
    });

    c.read(routerProvider).push(AppRoutes.khqr(order.id));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    for (var i = 0; i < 5 * 60; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PaymentResultScreen), findsOneWidget);
    final result = tester.widget<PaymentResultScreen>(
      find.byType(PaymentResultScreen),
    );
    expect(result.outcome.isPaid, isFalse);
    expect(
      result.outcome.payment.failureReason,
      'The QR code expired before payment was received.',
    );
  });

  testWidgets('Cancel payment goes back to the cart', (tester) async {
    var now = testNow();
    final b = testBackend(clock: () => now);
    final c = await pumpMosApp(tester, backend: b);
    await signInAsDara(tester);

    late Order order;
    await tester.runAsync(() async {
      order = await createOrder(b);
    });

    final router = c.read(routerProvider);
    router.push(AppRoutes.cart);
    await tester.pumpAndSettle();
    router.push(AppRoutes.khqr(order.id));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.widgetWithIcon(InkWell, Icons.close));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CartScreen), findsOneWidget);
  });

  Future<Order> openWithSaver(WidgetTester tester, _FakeQrSaver saver) async {
    final b = testBackend();
    final c = await pumpMosApp(
      tester,
      backend: b,
      extraOverrides: [qrSaverProvider.overrideWithValue(saver)],
    );
    await signInAsDara(tester);
    late Order order;
    await tester.runAsync(() async {
      order = await createOrder(b);
    });
    c.read(routerProvider).push(AppRoutes.khqr(order.id));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // page slid in
    return order;
  }

  testWidgets('Save QR to photos saves the code and says so', (tester) async {
    final saver = _FakeQrSaver();
    final order = await openWithSaver(tester, saver);

    await tester.tap(find.text('Save QR to photos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Order made at testNow(), Thursday 29 Oct 2026, 10:12.
    expect(saver.calls, ['MOS-KHQR-order${order.id}-20261029-1012']);
    expect(find.text('QR code saved to Photos.'), findsOneWidget);
  });

  testWidgets('when saving fails, the customer is told', (tester) async {
    final saver = _FakeQrSaver()..throws = true;
    await openWithSaver(tester, saver);

    await tester.tap(find.text('Save QR to photos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(saver.calls, isEmpty);
    expect(find.text('Could not save the QR code.'), findsOneWidget);
    expect(find.text('QR code saved to Photos.'), findsNothing);
  });
}
