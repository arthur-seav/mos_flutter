import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/cart/cart_controller.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/models/cart_item.dart';
import 'package:mos_app/data/models/drink_option.dart';
import 'package:mos_app/data/models/money.dart';
import 'package:mos_app/data/models/product.dart';
import 'package:mos_app/data/repository_providers.dart';

void main() {
  late ProviderContainer container;
  late MockMenuRepository menu;
  CartController cart() => container.read(cartControllerProvider.notifier);
  List<CartItem> lines() => container.read(cartControllerProvider);
  Money total() => container.read(cartTotalProvider);

  Product drink(int id, String name, double price) => Product(
    id: id,
    categoryId: 1,
    name: name,
    basePrice: Money.dollars(price),
  );
  final latte = drink(18, 'Latte', 3);
  final americano = drink(2, 'Americano', 2.5);
  final large = DrinkOption(
    id: 103,
    groupId: 1,
    name: 'Large',
    extraPrice: Money.dollars(1),
  );
  const small = DrinkOption(id: 101, groupId: 1, name: 'Small');

  CartItem item(DrinkOption size, int qty, {Product? product}) =>
      CartItem(product: product ?? latte, options: [size], quantity: qty);

  setUp(() {
    menu = MockMenuRepository(latency: Duration.zero);
    container = ProviderContainer.test(
      overrides: [menuRepositoryProvider.overrideWithValue(menu)],
    );
  });

  test('starts empty', () {
    expect(lines(), isEmpty);
    expect(container.read(cartCountProvider), 0);
    expect(total(), Money.zero);
  });

  test('the same drink with the same options adds to its quantity', () {
    cart().add(item(large, 1));
    cart().add(item(large, 2));
    expect(lines(), hasLength(1));
    expect(lines().single.quantity, 3);
  });

  test('different options make a separate line with its own id', () {
    cart().add(item(large, 1));
    cart().add(item(small, 1));
    expect(lines(), hasLength(2));
    expect(lines()[0].lineId, isNot(lines()[1].lineId));
    expect(container.read(cartCountProvider), 2);
    expect(total(), Money.dollars(7));
  });

  test('Undo puts back the cart from before the add', () {
    cart().add(item(large, 1));
    final before = cart().add(item(large, 1));
    expect(lines().single.quantity, 2);
    cart().restore(before);
    expect(lines().single.quantity, 1);
  });

  test('TC-16: change one quantity, remove the other; total follows', () {
    cart().add(item(large, 1)); // $4.00
    cart().add(item(small, 1, product: americano)); // $2.50
    expect(total(), Money.dollars(6.5));

    final latteLine = lines()[0].lineId;
    cart().setQuantity(latteLine, 3);
    expect(total(), Money.dollars(14.5));

    final removed = cart().remove(lines()[1].lineId);
    expect(removed!.product.name, 'Americano');
    expect(lines().map((l) => l.product.name), ['Latte']);
    expect(total(), Money.dollars(12));
  });

  test('quantity stays between 1 and 20', () {
    cart().add(item(large, 1));
    final id = lines().single.lineId;
    cart().setQuantity(id, 0);
    expect(lines().single.quantity, 1);
    cart().setQuantity(id, 50);
    expect(lines().single.quantity, 20);
    cart().add(item(large, 5));
    expect(lines().single.quantity, 20);
  });

  test('editing options keeps the line in place', () {
    cart().add(item(large, 1, product: americano));
    cart().add(item(large, 1));
    final latteLine = lines()[1].lineId;
    cart().replace(latteLine, item(small, 2));
    expect(lines()[1].lineId, latteLine);
    expect(lines()[1].optionSummary, 'Small');
    expect(lines()[1].quantity, 2);
  });

  test('editing into a drink already in the cart merges the two lines', () {
    cart().add(item(small, 1));
    cart().add(item(large, 2));
    cart().replace(lines()[1].lineId, item(small, 2));
    expect(lines(), hasLength(1));
    expect(lines().single.quantity, 3);
  });

  test(
    'TC-17 / BR-05: a drink that sold out is taken out before checkout',
    () async {
      cart().add(item(large, 1)); // Latte $4.00
      cart().add(item(small, 1, product: americano)); // $2.50
      menu.markSoldOut(americano.id);

      final removed = await cart().removeUnavailable();
      expect(removed.map((l) => l.product.name), ['Americano']);
      expect(lines().map((l) => l.product.name), ['Latte']);
      expect(total(), Money.dollars(4));
      expect(
        CartController.unavailableMessage(removed),
        'Americano is sold out and was removed from your cart.',
      );
    },
  );

  test('nothing sold out: the cart stays as it is', () async {
    cart().add(item(large, 1));
    expect(await cart().removeUnavailable(), isEmpty);
    expect(lines(), hasLength(1));
  });
}
