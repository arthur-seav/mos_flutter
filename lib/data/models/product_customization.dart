import 'package:flutter/foundation.dart' show immutable;

import 'drink_option.dart';
import 'money.dart';
import 'product.dart';

/// Everything the customization page needs for one drink.
@immutable
class ProductCustomization {
  const ProductCustomization({required this.product, required this.groups});

  final Product product;

  /// BR-01: the groups depend on the drink.
  final List<ProductOptionGroup> groups;

  /// The "from" price: base price with the cheapest choice in every
  /// required group. Lower than the base price when an option is a
  /// discount (Espresso, single shot).
  Money get lowestPrice => groups
      .where((g) => g.group.isRequired && g.options.isNotEmpty)
      .map(
        (g) => g.options
            .map((o) => o.extraPrice)
            .reduce((a, b) => a.compareTo(b) <= 0 ? a : b),
      )
      .fold(product.basePrice, (sum, cheapest) => sum + cheapest);
}
