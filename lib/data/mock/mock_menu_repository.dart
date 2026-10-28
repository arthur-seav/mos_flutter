import '../models/category.dart';
import '../models/menu_catalog.dart';
import '../models/money.dart';
import '../models/product.dart';
import '../repositories/menu_repository.dart';

/// The demo menu, based on the Figma screens and the SA test cases.
///
/// Mocha is sold out so TC-09 can be shown without the staff dashboard.
class MockMenuRepository implements MenuRepository {
  MockMenuRepository({this.latency = const Duration(milliseconds: 600)});

  final Duration latency;

  static const coffee = 1, tea = 2, frappe = 3, nonCoffee = 4;

  static const _categories = [
    Category(id: coffee, name: 'Coffee', sortOrder: 1),
    Category(id: tea, name: 'Tea', sortOrder: 2),
    Category(id: frappe, name: 'Frappé', sortOrder: 3),
    Category(id: nonCoffee, name: 'Non-coffee', sortOrder: 4),
  ];

  static final _products = [
    _p(1, coffee, 'Espresso', 2.00, 'Double shot, rich and bold'),
    _p(2, coffee, 'Americano', 2.50, 'Espresso topped with hot water'),
    _p(3, coffee, 'Cappuccino', 3.20, 'Espresso, steamed milk, thick foam'),
    _p(4, coffee, 'Caramel Latte', 3.50, 'Espresso, steamed milk, caramel'),
    _p(
      5,
      coffee,
      'Mocha',
      3.60,
      'Espresso, chocolate, steamed milk',
      available: false,
    ),
    _p(6, coffee, 'Flat White', 3.40, 'Ristretto with velvety microfoam'),
    _p(7, tea, 'Jasmine Green Tea', 2.20, 'Light, floral green tea'),
    _p(8, tea, 'Thai Milk Tea', 2.60, 'Spiced black tea with sweet milk'),
    _p(9, tea, 'Earl Grey Milk Tea', 2.80, 'Bergamot black tea with milk'),
    _p(10, tea, 'Matcha Latte', 3.30, 'Stone-ground matcha, steamed milk'),
    _p(11, frappe, 'Caramel Frappé', 3.90, 'Blended coffee, caramel, cream'),
    _p(12, frappe, 'Mocha Frappé', 3.90, 'Blended coffee, chocolate, cream'),
    _p(13, frappe, 'Matcha Frappé', 4.10, 'Blended matcha, milk, cream'),
    _p(14, nonCoffee, 'Hot Chocolate', 3.00, 'Rich cocoa with steamed milk'),
    _p(15, nonCoffee, 'Strawberry Milk', 2.80, 'Fresh strawberry, cold milk'),
    _p(16, nonCoffee, 'Lemon Soda', 2.20, 'Fresh lemon, sparkling water'),
    _p(
      17,
      nonCoffee,
      'Seasonal Smoothie',
      3.50,
      'No longer on the menu',
      active: false,
    ),
  ];

  /// Best sellers, most popular first (ids from [_products]).
  static const _popularIds = [4, 2, 3, 1, 10, 11];

  static Product _p(
    int id,
    int categoryId,
    String name,
    double price,
    String description, {
    bool available = true,
    bool active = true,
  }) => Product(
    id: id,
    categoryId: categoryId,
    name: name,
    description: description,
    basePrice: Money.dollars(price),
    isAvailable: available,
    isActive: active,
  );

  @override
  Future<MenuCatalog> fetchMenu() async {
    await Future<void>.delayed(latency);
    return MenuCatalog(categories: _categories, products: _products);
  }

  @override
  Future<List<Product>> fetchPopular({int limit = 6}) async {
    await Future<void>.delayed(latency);
    final byId = {for (final p in _products) p.id: p};
    return _popularIds
        .map((id) => byId[id]!)
        .where((p) => p.isActive)
        .take(limit)
        .toList();
  }
}
