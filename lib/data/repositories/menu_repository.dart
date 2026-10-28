import '../models/menu_catalog.dart';
import '../models/product.dart';

/// Where the menu comes from (NFR-09). Mock today, the backend API later.
abstract interface class MenuRepository {
  /// Categories and drinks for the customer app (FR-06, FR-07).
  Future<MenuCatalog> fetchMenu();

  /// Drinks for "Popular now" on Home. The backend will pick the best
  /// sellers (the same data as the admins' FR-35 report).
  Future<List<Product>> fetchPopular({int limit = 6});
}
