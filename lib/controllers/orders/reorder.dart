import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/drink_selection.dart';
import '../../data/models/order.dart';
import '../../data/repository_providers.dart';
import '../cart/cart_controller.dart';

@immutable
class ReorderResult {
  const ReorderResult({required this.added, required this.unavailable});

  /// How many cart lines went in.
  final int added;

  /// Drinks left out: sold out or no longer on the menu.
  final List<String> unavailable;

  /// For the notice after "Reorder".
  String get message {
    if (added == 0) return 'None of these drinks are available right now.';
    if (unavailable.isEmpty) return "Added to your cart at today's prices.";
    final names = unavailable.join(', ');
    return "Added to your cart at today's prices. "
        '$names ${unavailable.length == 1 ? 'is' : 'are'} not available, '
        'so ${unavailable.length == 1 ? 'it was' : 'they were'} left out.';
  }
}

/// "Reorder" (SA §4.2.4.5, §4.2.5.1, TC-28): the same drinks and options
/// go into the cart at today's prices. Drinks that sold out or left the
/// menu are left out (BR-05); options a drink no longer offers fall back
/// to today's defaults.
final reorderProvider = Provider<Future<ReorderResult> Function(Order)>(
  (ref) => (order) async {
    final menu = ref.read(menuRepositoryProvider);
    final cart = ref.read(cartControllerProvider.notifier);
    var added = 0;
    final unavailable = <String>[];
    for (final item in order.items) {
      try {
        final customization = await menu.fetchCustomization(item.productId);
        if (customization.product.isSoldOut) {
          unavailable.add(item.productName);
          continue;
        }
        final selection = DrinkSelection.fromOptionIds(
          customization,
          item.optionIds,
          quantity: item.quantity,
        );
        cart.add(selection.toCartItem());
        added++;
      } on Object {
        unavailable.add(item.productName);
      }
    }
    return ReorderResult(added: added, unavailable: unavailable);
  },
);
