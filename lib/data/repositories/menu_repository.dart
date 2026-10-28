import '../models/menu_catalog.dart';
import '../models/product.dart';
import '../models/product_customization.dart';

/// Where the menu comes from (NFR-09). Mock today, the backend API later.
abstract interface class MenuRepository {
  /// Categories and drinks for the customer app (FR-06, FR-07).
  Future<MenuCatalog> fetchMenu();

  /// Drinks for "Popular now" on Home. The backend will pick the best
  /// sellers (the same data as the admins' FR-35 report).
  Future<List<Product>> fetchPopular({int limit = 6});

  /// The option groups, options, prices and defaults for one drink
  /// (FR-08, BR-01). Throws [StateError] for an unknown or removed drink.
  Future<ProductCustomization> fetchCustomization(int productId);

  /// Of [productIds], the drinks that can no longer be ordered: sold out
  /// today or removed from the menu. Checked before checkout (BR-05).
  Future<Set<int>> fetchUnavailable(Iterable<int> productIds);
}
