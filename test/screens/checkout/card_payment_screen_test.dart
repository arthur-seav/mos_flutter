import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mos_app/data/mock/mock_backend.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/models/order.dart';
import 'package:mos_app/router.dart';
import 'package:mos_app/screens/checkout/payment_result_screen.dart';
import 'package:mos_app/widgets/common/labeled_text_field.dart';

import '../../helpers.dart';

void main() {
  /// Opens checkout for a fresh order and pushes the card payment page.
  Future<Order> openCardPayment(
    WidgetTester tester,
    MockBackend backend,
    ProviderContainer container,
  ) async {
    late Order order;
    await tester.runAsync(() async {
      order = await backend.orders.createOrder(
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
    });
    container.read(routerProvider).push(AppRoutes.card(order.id));
    await tester.pumpAndSettle();
    return order;
  }

  testWidgets('shows the saved card, never the full number', (tester) async {
    final backend = testBackend();
    final container = await pumpMosApp(tester, backend: backend);
    await continueAsGuest(tester);
    await openCardPayment(tester, backend, container);

    // Once on the card picture, once in the summary below it.
    expect(find.text('•••• •••• •••• 4242'), findsNWidgets(2));
    expect(find.text('DARA SOK'), findsNWidgets(2));
    expect(find.text('09/28'), findsNWidgets(2));
    // Latte, Medium: $3.50.
    expect(find.text(r'Pay $3.50'), findsOneWidget);
    expect(find.textContaining('4242424242424242'), findsNothing);
  });

  testWidgets('paying with the saved card shows the success result', (
    tester,
  ) async {
    final backend = testBackend();
    final container = await pumpMosApp(tester, backend: backend);
    await continueAsGuest(tester);
    await openCardPayment(tester, backend, container);

    await tester.tap(find.byTooltip('Pay'));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentResultScreen), findsOneWidget);
    final screen = tester.widget<PaymentResultScreen>(
      find.byType(PaymentResultScreen),
    );
    expect(screen.outcome.isPaid, isTrue);
  });

  Future<void> openAddCardForm(WidgetTester tester) async {
    await tester.dragUntilVisible(
      find.text('Add card'),
      find.byType(ListView),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add card'));
    await tester.pumpAndSettle();
  }

  testWidgets('adding a declined card and paying shows the failure result', (
    tester,
  ) async {
    final backend = testBackend();
    final container = await pumpMosApp(tester, backend: backend);
    await continueAsGuest(tester);
    await openCardPayment(tester, backend, container);

    await openAddCardForm(tester);

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

    // The sheet closed and the new card is selected: the summary under
    // the cards now shows it.
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('•••• •••• •••• 0002'), findsNWidgets(2));
    expect(find.text('•••• •••• •••• 4242'), findsOneWidget); // picture only

    await tester.tap(find.byTooltip('Pay'));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentResultScreen), findsOneWidget);
    final screen = tester.widget<PaymentResultScreen>(
      find.byType(PaymentResultScreen),
    );
    expect(screen.outcome.isPaid, isFalse);
    expect(screen.outcome.payment.failureReason, 'Your card was declined.');
  });

  testWidgets('the CVV field is obscured', (tester) async {
    final backend = testBackend();
    final container = await pumpMosApp(tester, backend: backend);
    await continueAsGuest(tester);
    await openCardPayment(tester, backend, container);

    await openAddCardForm(tester);

    final cvvField = tester.widget<LabeledTextField>(
      find.byWidgetPredicate((w) => w is LabeledTextField && w.label == 'CVV'),
    );
    expect(cvvField.obscureText, isTrue);
  });

  group('add-card form validation', () {
    Future<void> pumpForm(WidgetTester tester) async {
      final backend = testBackend();
      final container = await pumpMosApp(tester, backend: backend);
      await continueAsGuest(tester);
      await openCardPayment(tester, backend, container);
      await openAddCardForm(tester);
    }

    testWidgets('invalid card number', (tester) async {
      await pumpForm(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, '1234 5678 9012 3456'),
        '4242 4242 4242 4241',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add card'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid card number.'), findsOneWidget);
    });

    testWidgets('expired date', (tester) async {
      await pumpForm(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'MM/YY'),
        '09/26',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Add card'));
      await tester.pumpAndSettle();
      expect(find.text('This card has expired.'), findsOneWidget);
    });

    testWidgets('invalid CVV', (tester) async {
      await pumpForm(tester);
      await tester.enterText(find.widgetWithText(TextFormField, '123'), '12');
      await tester.tap(find.widgetWithText(FilledButton, 'Add card'));
      await tester.pumpAndSettle();
      expect(find.text('Use the 3 or 4 digits.'), findsOneWidget);
    });
  });
}
