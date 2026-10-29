import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/cart/cart_controller.dart';
import 'package:mos_app/controllers/orders/reorder.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/models/money.dart';
import 'package:mos_app/data/models/order.dart';

import '../../helpers.dart';

// A past order, at old prices: 2 Latte Large Iced Less sugar ($3.80 each
// then), 1 Mocha (sold out today), 1 Espresso marked Iced (Espresso is hot
// only today, TC-10).
const latte = OrderItem(
  productId: 18,
  productName: 'Latte',
  optionIds: [
    MockMenuRepository.large,
    MockMenuRepository.iced,
    MockMenuRepository.regularIce,
    MockMenuRepository.lessSugar,
  ],
  optionNames: ['Large', 'Iced', 'Regular ice', 'Less sugar'],
  unitPrice: Money.cents(380),
  quantity: 2,
);
const mocha = OrderItem(
  productId: 5,
  productName: 'Mocha',
  optionNames: [],
  unitPrice: Money.cents(360),
  quantity: 1,
);
const espresso = OrderItem(
  productId: 1,
  productName: 'Espresso',
  optionIds: [MockMenuRepository.iced, MockMenuRepository.tripleShot],
  optionNames: ['Iced', 'Triple shot'],
  unitPrice: Money.cents(250),
  quantity: 1,
);

Order pastOrder(List<OrderItem> items) => Order(
  id: 3,
  status: OrderStatus.completed,
  pickupType: PickupType.asap,
  createdAt: DateTime(2026, 10, 10, 8, 45),
  totalAmount: const Money.cents(1000),
  items: items,
);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer.test(overrides: testBackend().overrides);
  });

  test("TC-28: same drinks and options, at today's prices", () async {
    final result = await container.read(reorderProvider)(pastOrder([latte]));
    expect(result.added, 1);
    expect(result.message, "Added to your cart at today's prices.");

    final line = container.read(cartControllerProvider).single;
    expect(line.product.name, 'Latte');
    expect(line.quantity, 2);
    expect(line.options.map((o) => o.id), [
      MockMenuRepository.large,
      MockMenuRepository.iced,
      MockMenuRepository.regularIce,
      MockMenuRepository.lessSugar,
    ]);
    // Today: Latte $3.00 + Large $1.00 (TC-14) = $4.00, not the old $3.80.
    expect(line.unitPrice, const Money.cents(400));
  });

  test(
    'BR-05: a sold-out drink is left out, and the customer is told',
    () async {
      final result = await container.read(reorderProvider)(
        pastOrder([latte, mocha]),
      );
      expect(result.added, 1);
      expect(result.unavailable, ['Mocha']);
      expect(
        result.message,
        "Added to your cart at today's prices. Mocha is not available, so it "
        'was left out.',
      );
      expect(
        container.read(cartControllerProvider).map((l) => l.product.name),
        ['Latte'],
      );
    },
  );

  test(
    'an option the drink no longer offers falls back to the default',
    () async {
      await container.read(reorderProvider)(pastOrder([espresso]));
      final line = container.read(cartControllerProvider).single;
      // Iced is gone (Espresso is hot only); Triple shot is kept.
      expect(line.options.map((o) => o.id), contains(MockMenuRepository.hot));
      expect(
        line.options.map((o) => o.id),
        isNot(contains(MockMenuRepository.iced)),
      );
      expect(
        line.options.map((o) => o.id),
        contains(MockMenuRepository.tripleShot),
      );
      // $2.00 + Triple $0.50.
      expect(line.unitPrice, const Money.cents(250));
    },
  );

  test('nothing available: nothing added', () async {
    final result = await container.read(reorderProvider)(pastOrder([mocha]));
    expect(result.added, 0);
    expect(result.message, 'None of these drinks are available right now.');
    expect(container.read(cartControllerProvider), isEmpty);
  });
}
