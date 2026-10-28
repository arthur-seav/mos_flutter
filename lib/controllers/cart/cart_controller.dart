import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/cart_item.dart';
import '../../data/models/drink_selection.dart';
import '../../data/models/money.dart';
import '../../data/repository_providers.dart';

/// The cart, kept in the app until checkout (SA §3.5: no cart table).
///
/// FR-10: add drinks, change quantities, remove items, edit options.
/// BR-05: sold-out drinks are taken out before checkout.
final cartControllerProvider = NotifierProvider<CartController, List<CartItem>>(
  CartController.new,
);

/// Number of drinks in the cart (quantities added up): the Home badge
/// and the Menu cart bar.
final cartCountProvider = Provider<int>(
  (ref) =>
      ref.watch(cartControllerProvider).fold(0, (sum, l) => sum + l.quantity),
);

/// BR-03: all lines added up.
final cartTotalProvider = Provider<Money>(
  (ref) => ref
      .watch(cartControllerProvider)
      .fold(Money.zero, (sum, l) => sum + l.lineTotal),
);

class CartController extends Notifier<List<CartItem>> {
  int _nextLineId = 1;

  @override
  List<CartItem> build() => const [];

  CartItem? line(int lineId) =>
      state.where((l) => l.lineId == lineId).firstOrNull;

  /// Adds [item]. The same drink with the same options only adds to that
  /// line's quantity (up to [DrinkSelection.maxQuantity]).
  ///
  /// Returns the cart as it was before, for "Undo".
  List<CartItem> add(CartItem item) {
    final before = state;
    final index = state.indexWhere((l) => l.sameDrinkAs(item));
    if (index == -1) {
      state = [...state, item.withLineId(_nextLineId++)];
    } else {
      final l = state[index];
      state = _replaceAt(
        index,
        l.withQuantity(_clamp(l.quantity + item.quantity)),
      );
    }
    return before;
  }

  /// After a successful payment: the drinks are now an order.
  void clear() => state = const [];

  /// Puts back a cart returned by [add] ("Undo").
  void restore(List<CartItem> before) => state = before;

  /// TC-16. Kept between 1 and [DrinkSelection.maxQuantity]; to take a
  /// drink out, use [remove].
  void setQuantity(int lineId, int quantity) {
    final index = state.indexWhere((l) => l.lineId == lineId);
    if (index == -1) return;
    state = _replaceAt(index, state[index].withQuantity(_clamp(quantity)));
  }

  /// TC-16. Returns the removed line, or null if it was not there.
  CartItem? remove(int lineId) {
    final removed = line(lineId);
    if (removed != null) {
      state = [
        for (final l in state)
          if (l.lineId != lineId) l,
      ];
    }
    return removed;
  }

  /// "Edit options": swaps line [lineId] for [item], in the same place.
  /// If the new options match another line, the two lines become one.
  void replace(int lineId, CartItem item) {
    final index = state.indexWhere((l) => l.lineId == lineId);
    if (index == -1) {
      add(item);
      return;
    }
    final twin = state.indexWhere(
      (l) => l.lineId != lineId && l.sameDrinkAs(item),
    );
    if (twin == -1) {
      state = _replaceAt(index, item.withLineId(lineId));
      return;
    }
    final merged = state[twin].withQuantity(
      _clamp(state[twin].quantity + item.quantity),
    );
    state = [
      for (var i = 0; i < state.length; i++)
        if (i == twin) merged else if (i != index) state[i],
    ];
  }

  /// BR-05 / TC-17: asks the store which drinks in the cart can no longer
  /// be ordered, takes them out, and returns them so the page can say so.
  Future<List<CartItem>> removeUnavailable() async {
    final ids = state.map((l) => l.product.id).toSet();
    if (ids.isEmpty) return const [];
    final gone = await ref.read(menuRepositoryProvider).fetchUnavailable(ids);
    if (gone.isEmpty) return const [];
    final removed = [
      for (final l in state)
        if (gone.contains(l.product.id)) l,
    ];
    state = [
      for (final l in state)
        if (!gone.contains(l.product.id)) l,
    ];
    return removed;
  }

  /// "Mocha is sold out and was removed from your cart."
  static String unavailableMessage(List<CartItem> removed) {
    final names = removed.map((l) => l.product.name).toSet().toList();
    final list = names.length == 1
        ? names.single
        : '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
    return names.length == 1
        ? '$list is sold out and was removed from your cart.'
        : '$list are sold out and were removed from your cart.';
  }

  static int _clamp(int q) => q.clamp(1, DrinkSelection.maxQuantity);

  List<CartItem> _replaceAt(int index, CartItem item) => [
    for (var i = 0; i < state.length; i++) i == index ? item : state[i],
  ];
}
