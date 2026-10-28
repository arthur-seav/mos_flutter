import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/menu_catalog.dart';
import '../../../data/models/product.dart';
import '../../../data/repository_providers.dart';
import 'menu_filter_controller.dart';

/// The whole menu, loaded once and shared by Home and Menu.
///
/// A `FutureProvider` gives screens an `AsyncValue`: loading, error or data.
/// `ref.invalidate(menuCatalogProvider)` loads it again (pull to refresh,
/// "Try again").
final menuCatalogProvider = FutureProvider<MenuCatalog>(
  (ref) => ref.watch(menuRepositoryProvider).fetchMenu(),
);

/// "Popular now" on Home.
final popularProductsProvider = FutureProvider<List<Product>>(
  (ref) => ref.watch(menuRepositoryProvider).fetchPopular(),
);

/// What the Menu page shows: the catalog after the category and search
/// filters. Recomputed whenever either of them changes.
final menuSectionsProvider = Provider<AsyncValue<List<MenuSection>>>((ref) {
  final filter = ref.watch(menuFilterProvider);
  return ref
      .watch(menuCatalogProvider)
      .whenData(
        (catalog) => catalog.sections(
          categoryId: filter.categoryId,
          query: filter.query,
        ),
      );
});
