import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/cart/cart_controller.dart';
import 'package:mos_app/data/models/order.dart';
import 'package:mos_app/screens/checkout/card_payment_screen.dart';
import 'package:mos_app/screens/checkout/checkout_screen.dart';
import 'package:mos_app/screens/checkout/khqr_payment_screen.dart';
import 'package:mos_app/screens/checkout/payment_result_screen.dart';
import 'package:mos_app/screens/orders/order_tracking_screen.dart';
import 'package:mos_app/widgets/checkout/choice_card.dart';

import '../helpers.dart';

/// The whole way through, as a customer would: Menu -> drink -> cart ->
/// checkout -> payment -> result. Only the taps a person would make.
void main() {
  Future<void> pumpFrames(WidgetTester tester, [int n = 6]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Home -> Caramel Latte (defaults, $4.00) -> Add to cart -> cart ->
  /// Go to checkout.
  Future<void> orderCaramelLatte(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Add Caramel Latte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'Add to cart · $4.00'));
    await tester.pumpAndSettle();
    // The "Added to cart" notice covers the cart button until it closes.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go to checkout'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutScreen), findsOneWidget);
  }

  testWidgets(
    'TC-21: pay by KHQR -> success with a pickup code; cart emptied',
    (tester) async {
      var now = testNow();
      final backend = testBackend(clock: () => now);
      final container = await pumpMosApp(tester, backend: backend);
      await signInAsDara(tester);
      await orderCaramelLatte(tester);

      await tester.tap(find.text(r'Pay $4.00'));
      await pumpFrames(tester);
      expect(find.byType(KhqrPaymentScreen), findsOneWidget);
      expect(find.text(r'$4.00'), findsOneWidget);

      for (var i = 0; i < 6; i++) {
        now = now.add(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }
      await pumpFrames(tester);

      expect(find.byType(PaymentResultScreen), findsOneWidget);
      expect(find.text('Payment successful'), findsOneWidget);
      expect(find.text('#A1024'), findsOneWidget);
      expect(find.text('10:12 AM'), findsOneWidget); // paid at 10:12:06
      expect(container.read(cartControllerProvider), isEmpty);

      await tester.tap(find.text('Track my order'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderTrackingScreen), findsOneWidget);
    },
  );

  testWidgets('TC-22: declined card -> failure -> change to KHQR -> paid; the '
      'order has two payments, failed then paid', (tester) async {
    var now = testNow();
    final backend = testBackend(clock: () => now);
    await pumpMosApp(tester, backend: backend);
    await signInAsDara(tester);
    await orderCaramelLatte(tester);

    // Card, and add the gateway's "declined" test card.
    await tester.tap(find.widgetWithText(ChoiceCard, 'Credit / Debit card'));
    await tester.pump();
    await tester.tap(find.text(r'Pay $4.00'));
    await tester.pumpAndSettle();
    expect(find.byType(CardPaymentScreen), findsOneWidget);
    await tester.tap(find.text('Add card'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, '1234 5678 9012 3456'),
      '4000 0000 0000 0002',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'DARA SOK'),
      'Dara Sok',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'MM/YY'),
      '12/30',
    );
    await tester.enterText(find.widgetWithText(TextFormField, '123'), '123');
    await tester.tap(find.widgetWithText(FilledButton, 'Add card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(r'Pay $4.00'));
    await tester.pumpAndSettle();

    expect(find.text('Payment failed'), findsOneWidget);
    expect(
      find.text('Your card was declined. You have not been charged.'),
      findsOneWidget,
    );
    // Staff don't see it yet. (Backend calls from the test body run in
    // real async; widget tests run on fake time.)
    late Order unpaid;
    await tester.runAsync(() async {
      unpaid = await backend.orders.fetchOrder(1);
    });
    expect(unpaid.status, OrderStatus.pendingPayment);

    await tester.tap(find.text('Change payment method'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutScreen), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceCard, 'KHQR'));
    await tester.pump();
    await tester.tap(find.text(r'Pay $4.00'));
    await pumpFrames(tester);
    expect(find.byType(KhqrPaymentScreen), findsOneWidget);
    for (var i = 0; i < 6; i++) {
      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }
    await pumpFrames(tester);
    expect(find.text('Payment successful'), findsOneWidget);

    // Same order, no second one.
    late Order order;
    await tester.runAsync(() async {
      order = await backend.orders.fetchOrder(1);
    });
    expect(order.status, OrderStatus.placed);
    expect(order.payments.map((p) => (p.method, p.status)), [
      (PaymentMethod.card, PaymentStatus.failed),
      (PaymentMethod.khqr, PaymentStatus.paid),
    ]);
    await tester.tap(find.text('Return to Home'));
    await tester.pumpAndSettle();
  });
}
