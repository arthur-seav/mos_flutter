import 'package:flutter/foundation.dart' show immutable;

import 'drink_option.dart';
import 'product.dart';

/// Everything the customization page needs for one drink.
@immutable
class ProductCustomization {
  const ProductCustomization({required this.product, required this.groups});

  final Product product;

  /// BR-01: the groups depend on the drink.
  final List<ProductOptionGroup> groups;
}
