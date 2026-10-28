import 'package:flutter/foundation.dart';

import 'money.dart';

/// A drink on the menu (data dictionary: `products`).
@immutable
class Product {
  const Product({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.basePrice,
    this.description,
    this.imageUrl,
    this.isAvailable = true,
    this.isActive = true,
  });

  final int id;
  final int categoryId;
  final String name;
  final String? description;
  final String? imageUrl;

  /// Price before size and add-on charges.
  final Money basePrice;

  /// False = sold out today (FR-22). Still shown, but cannot be added
  /// to the cart (BR-05, TC-09).
  final bool isAvailable;

  /// False = removed from the menu (FR-25). Never shown to customers.
  final bool isActive;

  bool get isSoldOut => !isAvailable;

  /// TC-08: search matches the drink name, ignoring case.
  bool matches(String query) =>
      name.toLowerCase().contains(query.trim().toLowerCase());
}
