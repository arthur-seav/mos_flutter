import 'package:flutter/foundation.dart' show immutable, listEquals;

import 'drink_option.dart';
import 'money.dart';
import 'product.dart';

/// One line in the cart: a drink with its options and a quantity.
/// The cart lives in the app until checkout (SA §3.5), so this has no table.
@immutable
class CartItem {
  const CartItem({
    required this.product,
    required this.options,
    required this.quantity,
  });

  final Product product;
  final List<DrinkOption> options;
  final int quantity;

  /// BR-03: base price + the options' extra prices.
  Money get unitPrice =>
      options.fold(product.basePrice, (sum, o) => sum + o.extraPrice);

  Money get lineTotal => unitPrice * quantity;

  /// "Medium · Iced · Less · Oat milk"
  String get optionSummary => options.map((o) => o.name).join(' · ');

  /// Same drink with the same options: added again, it only adds quantity.
  bool sameDrinkAs(CartItem other) =>
      other.product.id == product.id &&
      listEquals(
        other.options.map((o) => o.id).toList(),
        options.map((o) => o.id).toList(),
      );

  CartItem withQuantity(int value) =>
      CartItem(product: product, options: options, quantity: value);
}
