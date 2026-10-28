import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cart_item.dart';
import '../../data/models/money.dart';

/// The cart, kept in the app until checkout (SA §3.5: no cart table).
///
/// This step only adds drinks; the cart page (edit quantity, remove,
/// FR-10) comes next.
final cartControllerProvider = NotifierProvider<CartController, List<CartItem>>(
  CartController.new,
);

class CartController extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => const [];

  /// The same drink with the same options only adds to its quantity.
  void add(CartItem item) {
    final index = state.indexWhere((line) => line.sameDrinkAs(item));
    if (index == -1) {
      state = [...state, item];
      return;
    }
    final line = state[index];
    state = [
      for (var i = 0; i < state.length; i++)
        i == index
            ? line.withQuantity(line.quantity + item.quantity)
            : state[i],
    ];
  }

  int get itemCount => state.fold(0, (sum, line) => sum + line.quantity);

  Money get total =>
      state.fold(Money.zero, (sum, line) => sum + line.lineTotal);
}
