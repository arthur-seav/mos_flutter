import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/controllers/cart/cart_controller.dart';
import 'package:mos_app/data/models/cart_item.dart';
import 'package:mos_app/data/models/drink_option.dart';
import 'package:mos_app/data/models/money.dart';
import 'package:mos_app/data/models/product.dart';

void main() {
  late ProviderContainer container;
  CartController cart() => container.read(cartControllerProvider.notifier);

  final latte = Product(
    id: 18,
    categoryId: 1,
    name: 'Latte',
    basePrice: Money.dollars(3),
  );
  final large = DrinkOption(
    id: 103,
    groupId: 1,
    name: 'Large',
    extraPrice: Money.dollars(1),
  );
  const small = DrinkOption(id: 101, groupId: 1, name: 'Small');

  CartItem item(DrinkOption size, int qty) =>
      CartItem(product: latte, options: [size], quantity: qty);

  setUp(() => container = ProviderContainer.test());

  test('starts empty', () {
    expect(container.read(cartControllerProvider), isEmpty);
    expect(cart().itemCount, 0);
  });

  test('the same drink with the same options adds to its quantity', () {
    cart().add(item(large, 1));
    cart().add(item(large, 2));
    final lines = container.read(cartControllerProvider);
    expect(lines, hasLength(1));
    expect(lines.single.quantity, 3);
  });

  test('different options make a separate line', () {
    cart().add(item(large, 1));
    cart().add(item(small, 1));
    expect(container.read(cartControllerProvider), hasLength(2));
    expect(cart().itemCount, 2);
    expect(cart().total, Money.dollars(7));
  });
}
