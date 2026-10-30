import '../models/menu_catalog.dart';
import '../models/product.dart';
import '../models/product_customization.dart';
import '../models/store_info.dart';
import '../repositories/menu_repository.dart';
import '../repositories/store_repository.dart';
import 'api_client.dart';
import 'api_json.dart';

/// The public menu (`/api/app/menu/**`). No sign-in needed (FR-01).
class ApiMenuRepository implements MenuRepository {
  ApiMenuRepository(this._api);

  final ApiClient _api;

  @override
  Future<MenuCatalog> fetchMenu() async {
    final json = await _api.get('/api/app/menu') as Json;
    return MenuCatalog(
      categories: [
        for (final c in (json['categories'] as List).cast<Json>())
          categoryFrom(c),
      ],
      products: [
        for (final p in (json['products'] as List).cast<Json>())
          productFrom(p, resolveUrl: _api.resolve),
      ],
    );
  }

  @override
  Future<List<Product>> fetchPopular({int limit = 6}) async {
    final json = await _api.get(
      '/api/app/menu/popular',
      query: {'limit': '$limit'},
    );
    return [
      for (final p in (json as List).cast<Json>())
        productFrom(p, resolveUrl: _api.resolve),
    ];
  }

  @override
  Future<ProductCustomization> fetchCustomization(int productId) async {
    try {
      final json = await _api.get(
        '/api/app/menu/products/$productId/customization',
      );
      return customizationFrom(json as Json, resolveUrl: _api.resolve);
    } on ApiException catch (e) {
      // The interface promises StateError for an unknown or removed drink.
      if (e.status == 404) throw StateError(e.message);
      rethrow;
    }
  }

  @override
  Future<Set<int>> fetchUnavailable(Iterable<int> productIds) async {
    final json =
        await _api.post('/api/app/menu/unavailable', {
              'productIds': productIds.toList(),
            })
            as Json;
    return (json['productIds'] as List).cast<int>().toSet();
  }
}

/// Store settings and opening hours (`/api/app/store`).
class ApiStoreRepository implements StoreRepository {
  ApiStoreRepository(this._api);

  final ApiClient _api;

  @override
  Future<StoreInfo> fetchStoreInfo() async =>
      storeInfoFrom(await _api.get('/api/app/store') as Json);
}
