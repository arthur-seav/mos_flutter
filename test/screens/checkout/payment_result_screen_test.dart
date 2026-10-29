import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/checkout/payment_outcome.dart';
import 'package:mos_app/data/models/money.dart';
import 'package:mos_app/data/models/order.dart';
import 'package:mos_app/router.dart';
import 'package:mos_app/screens/checkout/card_payment_screen.dart';
import 'package:mos_app/screens/checkout/checkout_screen.dart';
import 'package:mos_app/screens/checkout/khqr_payment_screen.dart';
import 'package:mos_app/screens/home/home_screen.dart';
import 'package:mos_app/screens/orders/order_tracking_screen.dart';

import '../../helpers.dart';

/// Builds the successful outcome used across these tests: order #A1024,
/// $7.00 paid via KHQR at 10:12 AM (SA §4.2.3.4, TC-21).
PaymentOutcome successOutcome() => PaymentOutcome(
  order: Order(
    id: 1,
    status: OrderStatus.placed,
    pickupType: PickupType.asap,
    items: const [],
    totalAmount: Money.dollars(7),
    createdAt: DateTime(2026, 10, 29, 10, 11),
    pickupCode: 'A1024',
    placedAt: DateTime(2026, 10, 29, 10, 12),
  ),
  payment: Payment(
    id: 1,
    orderId: 1,
    method: PaymentMethod.khqr,
    amount: Money.dollars(7),
    status: PaymentStatus.paid,
    createdAt: DateTime(2026, 10, 29, 10, 11),
    paidAt: DateTime(2026, 10, 29, 10, 12),
  ),
);

/// A declined card payment (TC-22).
PaymentOutcome cardFailureOutcome() => PaymentOutcome(
  order: Order(
    id: 1,
    status: OrderStatus.pendingPayment,
    pickupType: PickupType.asap,
    items: const [],
    totalAmount: Money.dollars(7),
    createdAt: DateTime(2026, 10, 29, 10, 11),
  ),
  payment: Payment(
    id: 2,
    orderId: 1,
    method: PaymentMethod.card,
    amount: Money.dollars(7),
    status: PaymentStatus.failed,
    createdAt: DateTime(2026, 10, 29, 10, 11),
    failureReason: 'Your card was declined.',
  ),
);

/// Same failure, but via KHQR, for the "Try again" KHQR branch.
PaymentOutcome khqrFailureOutcome() => PaymentOutcome(
  order: Order(
    id: 1,
    status: OrderStatus.pendingPayment,
    pickupType: PickupType.asap,
    items: const [],
    totalAmount: Money.dollars(7),
    createdAt: DateTime(2026, 10, 29, 10, 11),
  ),
  payment: Payment(
    id: 3,
    orderId: 1,
    method: PaymentMethod.khqr,
    amount: Money.dollars(7),
    status: PaymentStatus.failed,
    createdAt: DateTime(2026, 10, 29, 10, 11),
    failureReason: 'The QR code expired before payment was received.',
  ),
);

/// Pushes the result route with [outcome] as `extra` and settles the
/// opening frame, as the app itself does from a payment page.
Future<ProviderContainer> openResult(
  WidgetTester tester,
  PaymentOutcome outcome,
) async {
  final container = await pumpMosApp(tester);
  await signInAsDara(tester);
  container.read(routerProvider).push(AppRoutes.paymentResult, extra: outcome);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return container;
}

void main() {
  group('Payment successful (TC-21)', () {
    testWidgets('shows order, time, method and amount', (tester) async {
      await openResult(tester, successOutcome());

      expect(find.text('Payment successful'), findsOneWidget);
      expect(find.text('#A1024'), findsOneWidget);
      expect(find.text('10:12 AM'), findsOneWidget);
      expect(find.text('KHQR'), findsOneWidget);
      expect(find.text('\$7.00'), findsOneWidget);
      expect(
        find.text(
          '\$7.00 paid via KHQR. Your order has been sent to the store.',
        ),
        findsOneWidget,
      );
      expect(find.text('Taking you to your order...'), findsOneWidget);
    });

    testWidgets('"Track my order" opens that order\'s tracking page', (
      tester,
    ) async {
      await openResult(tester, successOutcome());

      await tester.tap(find.text('Track my order'));
      await tester.pumpAndSettle();

      final page = tester.widget<OrderTrackingScreen>(
        find.byType(OrderTrackingScreen),
      );
      expect(page.orderId, successOutcome().order.id);
    });

    testWidgets('"Return to Home" goes to Home', (tester) async {
      await openResult(tester, successOutcome());

      await tester.tap(find.text('Return to Home'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('auto-redirects to the tracking page after 5 seconds', (
      tester,
    ) async {
      await openResult(tester, successOutcome());

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.byType(OrderTrackingScreen), findsOneWidget);
    });
  });

  group('Payment failed (TC-22)', () {
    testWidgets('shows reason, amount, method and status', (tester) async {
      await openResult(tester, cardFailureOutcome());

      expect(find.text('Payment failed'), findsOneWidget);
      expect(
        find.text('Your card was declined. You have not been charged.'),
        findsOneWidget,
      );
      expect(find.text('\$7.00'), findsOneWidget);
      expect(find.text('Card'), findsOneWidget);
      expect(find.text('Not charged'), findsOneWidget);
    });

    testWidgets('"Try again" on a card failure goes to Card payment', (
      tester,
    ) async {
      await openResult(tester, cardFailureOutcome());

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(CardPaymentScreen), findsOneWidget);
    });

    testWidgets('"Try again" on a KHQR failure goes to KHQR payment', (
      tester,
    ) async {
      await openResult(tester, khqrFailureOutcome());

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.byType(KhqrPaymentScreen), findsOneWidget);
    });

    testWidgets('"Change payment method" goes back to Checkout', (
      tester,
    ) async {
      final container = await pumpMosApp(tester);
      await signInAsDara(tester);
      final router = container.read(routerProvider);
      router.push(AppRoutes.checkout);
      await tester.pumpAndSettle();
      router.push(AppRoutes.paymentResult, extra: cardFailureOutcome());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Change payment method'));
      await tester.pumpAndSettle();

      expect(find.byType(CheckoutScreen), findsOneWidget);
    });
  });
}
