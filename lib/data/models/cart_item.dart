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
    List<String>? optionLabels,
    this.lineId = 0,
  }) : _optionLabels = optionLabels;

  /// Which cart line this is, given by [CartController] when the drink is
  /// added. Stays the same when the quantity or options change, so the
  /// cart page can edit or remove the right line. 0 = not in the cart yet.
  final int lineId;

  final Product product;
  final List<DrinkOption> options;
  final int quantity;

  /// How each option reads in the cart ("Less ice"). Defaults to the
  /// option names.
  final List<String>? _optionLabels;

  List<String> get optionLabels =>
      _optionLabels ?? options.map((o) => o.name).toList();

  /// BR-03: base price + the options' extra prices.
  Money get unitPrice =>
      options.fold(product.basePrice, (sum, o) => sum + o.extraPrice);

  Money get lineTotal => unitPrice * quantity;

  /// "Medium · Iced · Less ice · Regular sugar · Oat milk"
  String get optionSummary => optionLabels.join(' · ');

  /// Same drink with the same options: added again, it only adds quantity.
  bool sameDrinkAs(CartItem other) =>
      other.product.id == product.id &&
      listEquals(
        other.options.map((o) => o.id).toList(),
        options.map((o) => o.id).toList(),
      );

  CartItem withQuantity(int value) => CartItem(
    product: product,
    options: options,
    optionLabels: _optionLabels,
    quantity: value,
    lineId: lineId,
  );

  CartItem withLineId(int value) => CartItem(
    product: product,
    options: options,
    optionLabels: _optionLabels,
    quantity: quantity,
    lineId: value,
  );
}
