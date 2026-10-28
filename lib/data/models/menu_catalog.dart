import 'package:flutter/foundation.dart' show immutable;

import 'category.dart';
import 'product.dart';

/// One heading on the Menu page and the drinks under it.
@immutable
class MenuSection {
  const MenuSection(this.category, this.products);

  final Category category;
  final List<Product> products;
}

/// The whole menu as the customer sees it: active categories in their
/// sort order, each with its active drinks (FR-06).
///
/// Filtering by category and search lives here, not in the screens, so it
/// can be unit-tested and reused by Home and Menu.
@immutable
class MenuCatalog {
  MenuCatalog({
    required List<Category> categories,
    required List<Product> products,
  }) : categories = List.unmodifiable(
         categories.where((c) => c.isActive).toList()
           ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
       ),
       products = List.unmodifiable(products.where((p) => p.isActive));

  final List<Category> categories;
  final List<Product> products;

  Product? productById(int id) => products.where((p) => p.id == id).firstOrNull;

  /// Sections for the Menu page.
  ///
  /// [categoryId] null means "All". A non-empty [query] keeps only drinks
  /// whose name matches (TC-08). Sections left empty are dropped, so an
  /// empty result means "nothing matches".
  List<MenuSection> sections({int? categoryId, String query = ''}) {
    final q = query.trim();
    return [
      for (final category in categories)
        if (categoryId == null || category.id == categoryId)
          MenuSection(category, [
            for (final p in products)
              if (p.categoryId == category.id && (q.isEmpty || p.matches(q))) p,
          ]),
    ].where((s) => s.products.isNotEmpty).toList();
  }
}
