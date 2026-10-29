import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/auth/auth_controller.dart';
import 'package:mos_app/controllers/cart/cart_controller.dart';
import 'package:mos_app/controllers/checkout/card_payment_controller.dart';
import 'package:mos_app/controllers/checkout/checkout_controller.dart';
import 'package:mos_app/controllers/checkout/khqr_payment_controller.dart';
import 'package:mos_app/data/mock/mock_auth_repository.dart';
import 'package:mos_app/data/mock/mock_backend.dart';
import 'package:mos_app/data/models/drink_selection.dart';
import 'package:mos_app/data/models/money.dart';
import 'package:mos_app/data/models/order.dart';
import 'package:mos_app/data/models/saved_card.dart';

import '../../helpers.dart';

void main() {
  late DateTime now;
  late MockBackend backend;
  late ProviderContainer container;

  CheckoutController checkout() =>
      container.read(checkoutControllerProvider.notifier);
  Future<CheckoutState> loaded() =>
      container.read(checkoutControllerProvider.future);

  Future<void> signIn() => container
      .read(authControllerProvider.notifier)
      .signIn(
        identifier: 'dara@example.com',
        password: MockAuthRepository.demoPassword,
      );

  /// Adds a drink with its default options.
  Future<void> add(int productId) async {
    final c = await backend.menu.fetchCustomization(productId);
    container
        .read(cartControllerProvider.notifier)
        .add(DrinkSelection.initial(c).toCartItem());
  }

  setUp(() {
    now = testNow(); // Thursday 10:12 AM, store open 7 AM - 9 PM
    backend = MockBackend(latency: Duration.zero, clock: () => now);
    container = ProviderContainer.test(overrides: backend.overrides);
    // Keep the auto-dispose providers alive between reads.
    container.listen(checkoutControllerProvider, (_, _) {});
  });

  test('opens with ASAP and KHQR', () async {
    final s = await loaded();
    expect(s.pickupType, PickupType.asap);
    expect(s.paymentMethod, PaymentMethod.khqr);
    expect(s.canPay, isTrue);
  });

  test('BR-06 / TC-18: a guest is asked to log in; the cart stays', () async {
    container.read(authControllerProvider.notifier).continueAsGuest();
    await add(18);
    await loaded();
    final result = await checkout().pay();
    expect(result, isA<CheckoutBlocked>());
    expect((result as CheckoutBlocked).needsLogin, isTrue);
    expect(container.read(cartControllerProvider), hasLength(1));
  });

  test(
    'FR-12: a customer gets an order to pay, priced by the backend',
    () async {
      await signIn();
      await add(18); // Latte, Medium: $3.50
      await add(1); // Espresso, Double: $2.00
      await loaded();
      final result = await checkout().pay();
      expect(result, isA<GoToPayment>());
      final order = (result as GoToPayment).order;
      expect(order.totalAmount, Money.dollars(5.5));
      expect(result.method, PaymentMethod.khqr);
    },
  );

  test('paying again without changes uses the same order (TC-22)', () async {
    await signIn();
    await add(18);
    await loaded();
    final first = await checkout().pay() as GoToPayment;
    checkout().choosePaymentMethod(PaymentMethod.card);
    final second = await checkout().pay() as GoToPayment;
    expect(second.order.id, first.order.id);
    expect(second.method, PaymentMethod.card);

    // A changed cart is a new order.
    await add(1);
    final third = await checkout().pay() as GoToPayment;
    expect(third.order.id, isNot(first.order.id));
  });

  test('TC-20: paused after the page opened: Pay is blocked', () async {
    await signIn();
    await add(18);
    expect((await loaded()).isPaused, isFalse);
    backend.store.pauseOnlineOrdering();
    final result = await checkout().pay();
    expect(result, isA<CheckoutBlocked>());
    expect((result as CheckoutBlocked).message, contains('paused'));
    final s = container.read(checkoutControllerProvider).requireValue;
    expect(s.isPaused, isTrue);
    expect(s.canPay, isFalse);
  });

  test('BR-05: a drink that sold out is taken out before the order', () async {
    await signIn();
    await add(18);
    await add(1);
    await loaded();
    backend.menu.markSoldOut(1);
    final result = await checkout().pay() as CheckoutBlocked;
    expect(
      result.message,
      'Espresso is sold out and was removed from your cart.',
    );
    expect(container.read(cartControllerProvider).map((l) => l.product.name), [
      'Latte',
    ]);
  });

  test('TC-19 / BR-07: only allowed slots can be chosen', () async {
    await loaded();
    expect(checkout().chooseSlot(DateTime(2026, 10, 29, 20, 5)), isFalse);
    // 10:12 + 5 min = 10:17.
    expect(checkout().chooseSlot(DateTime(2026, 10, 29, 10, 15)), isFalse);
    expect(
      container.read(checkoutControllerProvider).requireValue.pickupType,
      PickupType.asap,
    );
    expect(checkout().chooseSlot(DateTime(2026, 10, 29, 10, 20)), isTrue);
    final s = container.read(checkoutControllerProvider).requireValue;
    expect(s.pickupType, PickupType.scheduled);
    expect(s.pickupTime, DateTime(2026, 10, 29, 10, 20));
  });

  test('a chosen slot that becomes too soon blocks Pay', () async {
    await signIn();
    await add(18);
    await loaded();
    expect(checkout().chooseSlot(DateTime(2026, 10, 29, 10, 20)), isTrue);
    now = DateTime(2026, 10, 29, 10, 17); // 10:20 is now 3 min away
    final result = await checkout().pay();
    expect(result, isA<CheckoutBlocked>());
    expect(
      (result as CheckoutBlocked).message,
      contains('no longer available'),
    );
  });

  test('before opening, checkout starts on "Schedule for later"', () async {
    now = DateTime(2026, 10, 29, 6, 0);
    final s = await loaded();
    expect(s.pickupType, PickupType.scheduled);
    expect(s.canPay, isFalse); // until a slot is chosen
  });

  test('the note is kept to 200 characters', () async {
    await loaded();
    checkout().setNote('a' * 250);
    expect(
      container.read(checkoutControllerProvider).requireValue.note.length,
      maxNoteLength,
    );
  });

  group('KHQR', () {
    test('TC-21: paid after 5 s: success, cart emptied', () async {
      await signIn();
      await add(18);
      await loaded();
      final order = (await checkout().pay() as GoToPayment).order;
      final provider = khqrPaymentProvider(order.id);
      container.listen(provider, (_, _) {});
      final s = await container.read(provider.future);
      expect(s.stage, KhqrStage.waiting);
      expect(s.timeLeftText, '05:00');

      now = now.add(const Duration(seconds: 5));
      await container.read(provider.notifier).check();
      final done = container.read(provider).requireValue;
      expect(done.stage, KhqrStage.paid);
      expect(done.outcome!.order.pickupCode, 'A1024');
      expect(done.outcome!.payment.method, PaymentMethod.khqr);
      expect(container.read(cartControllerProvider), isEmpty);
    });

    test('cancel keeps the cart and the order unpaid', () async {
      await signIn();
      await add(18);
      await loaded();
      final order = (await checkout().pay() as GoToPayment).order;
      final provider = khqrPaymentProvider(order.id);
      container.listen(provider, (_, _) {});
      await container.read(provider.future);
      await container.read(provider.notifier).cancel();
      expect(container.read(provider).requireValue.stage, KhqrStage.cancelled);
      expect(container.read(cartControllerProvider), hasLength(1));
    });
  });

  group('Card', () {
    test('TC-22: declined card is a failed outcome; the cart stays', () async {
      await signIn();
      await add(18);
      await loaded();
      final order = (await checkout().pay() as GoToPayment).order;
      final provider = cardPaymentProvider(order.id);
      container.listen(provider, (_, _) {});
      final s = await container.read(provider.future);
      expect(s.cards.single.maskedNumber, '•••• •••• •••• 4242');
      expect(s.selectedCardId, 1);

      await container
          .read(provider.notifier)
          .addCard(
            const NewCard(
              number: '4000000000000002',
              holderName: 'Dara Sok',
              expiryMonth: 12,
              expiryYear: 2030,
              cvv: '123',
            ),
          );
      expect(container.read(provider).requireValue.selectedCard!.last4, '0002');

      final outcome = await container.read(provider.notifier).pay();
      expect(outcome!.isPaid, isFalse);
      expect(outcome.payment.failureReason, 'Your card was declined.');
      expect(container.read(cartControllerProvider), hasLength(1));

      container.read(provider.notifier).selectCard(1);
      final paid = await container.read(provider.notifier).pay();
      expect(paid!.isPaid, isTrue);
      expect(paid.order.payments, hasLength(2));
      expect(container.read(cartControllerProvider), isEmpty);
    });
  });
}
