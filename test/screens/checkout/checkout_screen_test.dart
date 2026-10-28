import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/cart/cart_controller.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/data/mock/mock_backend.dart';
import 'package:mos_app/data/models/drink_selection.dart';
import 'package:mos_app/data/models/product_customization.dart';
import 'package:mos_app/router.dart';
import 'package:mos_app/screens/auth/login_screen.dart';
import 'package:mos_app/screens/checkout/card_payment_screen.dart';
import 'package:mos_app/screens/checkout/checkout_screen.dart';
import 'package:mos_app/screens/checkout/khqr_payment_screen.dart';
import 'package:mos_app/widgets/checkout/choice_card.dart';

import '../../helpers.dart';

// At testNow(), Thursday 10:12 AM; the store is open 7 AM - 9 PM.
// Latte (Medium) $3.50 + Espresso (Double) $2.00 = $5.50.
const latte = 18, espresso = 1;

Future<void> signInAsDara(WidgetTester tester) async {
  await tester.enterText(find.byType(TextFormField).at(0), 'dara@example.com');
  await tester.enterText(
    find.byType(TextFormField).at(1),
    MockAuthRepository.demoPassword,
  );
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}

Future<void> addDrink(
  WidgetTester tester,
  ProviderContainer container,
  MockBackend backend,
  int productId,
) async {
  late final ProductCustomization c;
  await tester.runAsync(() async {
    c = await backend.menu.fetchCustomization(productId);
  });
  container
      .read(cartControllerProvider.notifier)
      .add(DrinkSelection.initial(c).toCartItem());
}

/// Opens checkout with Latte + Espresso in the cart, signed in as Dara
/// (or as a guest).
Future<ProviderContainer> openCheckout(
  WidgetTester tester,
  MockBackend backend, {
  bool guest = false,
}) async {
  final container = await pumpMosApp(tester, backend: backend);
  if (guest) {
    await continueAsGuest(tester);
  } else {
    await signInAsDara(tester);
  }
  await addDrink(tester, container, backend, latte);
  await addDrink(tester, container, backend, espresso);
  container.read(routerProvider).push(AppRoutes.checkout);
  await tester.pumpAndSettle();
  expect(find.byType(CheckoutScreen), findsOneWidget);
  return container;
}

Finder choice(String title) => find.widgetWithText(ChoiceCard, title);
bool isChosen(WidgetTester tester, String title) =>
    tester.widget<ChoiceCard>(choice(title)).selected;
FilledButton payButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.ancestor(
    of: find.text(r'Pay $5.50'),
    matching: find.byType(FilledButton),
  ),
);

void main() {
  testWidgets('opens with the store, ASAP, KHQR and the order summary', (
    tester,
  ) async {
    await openCheckout(tester, testBackend());
    expect(find.text('MOS Coffee'), findsOneWidget);
    expect(
      find.text('Pick up at the counter · Open until 9:00 PM'),
      findsOneWidget,
    );
    expect(isChosen(tester, 'As soon as possible'), isTrue);
    expect(find.text('Ready in about 10 min'), findsOneWidget);
    expect(isChosen(tester, 'KHQR'), isTrue);
    expect(isChosen(tester, 'Credit / Debit card'), isFalse);

    final page = find
        .descendant(
          of: find.byType(CheckoutScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(find.text('Total'), 200, scrollable: page);
    expect(find.text('Latte'), findsOneWidget);
    expect(find.text('Medium · Hot · Regular sugar'), findsOneWidget);
    expect(find.text('Double shot · Hot · No sugar'), findsOneWidget);
    expect(find.text(r'$5.50'), findsOneWidget); // the Total row
    expect(payButton(tester).onPressed, isNotNull);
  });

  testWidgets('TC-19 / BR-07: the schedule panel offers 10:45 AM to 8:00 PM', (
    tester,
  ) async {
    await openCheckout(tester, testBackend());
    await tester.tap(choice('Schedule for later'));
    await tester.pumpAndSettle();

    expect(find.text('Schedule pickup'), findsOneWidget);
    expect(find.text('Today · Store open until 9:00 PM'), findsOneWidget);
    expect(
      find.text('Slots must be at least 30 minutes from now.'),
      findsOneWidget,
    );
    expect(find.text('Choose a time'), findsOneWidget);

    // Too soon: listed but cannot be picked.
    await tester.tap(find.text('10:30 AM'));
    await tester.pump();
    expect(find.text('Confirm 10:30 AM'), findsNothing);

    // TC-19: 8:00 PM is the last slot; 8:15 PM is not offered.
    final grid = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('8:00 PM'),
      200,
      scrollable: grid,
    );
    expect(find.text('8:15 PM'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('10:45 AM'),
      -200,
      scrollable: grid,
    );
    await tester.tap(find.text('10:45 AM'));
    await tester.pump();
    await tester.tap(find.text('Confirm 10:45 AM'));
    await tester.pumpAndSettle();

    expect(isChosen(tester, 'Schedule for later'), isTrue);
    expect(isChosen(tester, 'As soon as possible'), isFalse);
    expect(find.text('Today at 10:45 AM · Change'), findsOneWidget);
  });

  testWidgets('TC-20: while ordering is paused the page says so; no Pay', (
    tester,
  ) async {
    final backend = testBackend();
    backend.store.pauseOnlineOrdering();
    await openCheckout(tester, backend);
    expect(find.text('Online ordering is paused'), findsOneWidget);
    expect(payButton(tester).onPressed, isNull);
  });

  testWidgets('TC-18: a guest is asked to log in and comes back to checkout '
      'with the cart kept', (tester) async {
    final container = await openCheckout(tester, testBackend(), guest: true);
    await tester.tap(find.text(r'Pay $5.50'));
    await tester.pumpAndSettle();
    expect(find.text('Log in to order'), findsOneWidget);

    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Continue as guest'), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget);

    await signInAsDara(tester);
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(container.read(cartControllerProvider).map((l) => l.product.name), [
      'Latte',
      'Espresso',
    ]);
  });

  testWidgets('a guest can say "Not now" and stay on checkout', (tester) async {
    await openCheckout(tester, testBackend(), guest: true);
    await tester.tap(find.text(r'Pay $5.50'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('Pay with KHQR opens the KHQR page', (tester) async {
    await openCheckout(tester, testBackend());
    await tester.tap(find.text(r'Pay $5.50'));
    // Not pumpAndSettle: the KHQR page counts down every second.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(KhqrPaymentScreen), findsOneWidget);
  });

  testWidgets('Pay by card opens the card page', (tester) async {
    await openCheckout(tester, testBackend());
    await tester.tap(choice('Credit / Debit card'));
    await tester.pump();
    expect(isChosen(tester, 'Credit / Debit card'), isTrue);
    await tester.tap(find.text(r'Pay $5.50'));
    await tester.pumpAndSettle();
    expect(find.byType(CardPaymentScreen), findsOneWidget);
  });

  testWidgets('BR-05: a drink that sold out is taken out with a message', (
    tester,
  ) async {
    final backend = testBackend();
    final container = await openCheckout(tester, backend);
    backend.menu.markSoldOut(espresso);
    await tester.tap(find.text(r'Pay $5.50'));
    await tester.pumpAndSettle();
    expect(
      find.text('Espresso is sold out and was removed from your cart.'),
      findsOneWidget,
    );
    expect(find.byType(CheckoutScreen), findsOneWidget);
    expect(find.text(r'Pay $3.50'), findsOneWidget);
    expect(container.read(cartControllerProvider).map((l) => l.product.name), [
      'Latte',
    ]);
  });

  testWidgets('before opening: ASAP is off and Pay waits for a time', (
    tester,
  ) async {
    await openCheckout(
      tester,
      testBackend(clock: () => DateTime(2026, 10, 29, 6, 0)),
    );
    expect(
      tester.widget<ChoiceCard>(choice('As soon as possible')).enabled,
      isFalse,
    );
    expect(
      find.text('Pick up at the counter · Opens at 7:00 AM'),
      findsOneWidget,
    );
    expect(payButton(tester).onPressed, isNull);
  });
}
