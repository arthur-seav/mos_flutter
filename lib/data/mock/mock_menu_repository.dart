import '../models/category.dart';
import '../models/drink_option.dart';
import '../models/menu_catalog.dart';
import '../models/money.dart';
import '../models/product.dart';
import '../models/product_customization.dart';
import '../repositories/menu_repository.dart';

/// The demo menu, based on the Figma screens and the SA test cases.
///
/// Mocha is sold out so TC-09 can be shown without the staff dashboard.
/// Drink options follow the test cases: Espresso is hot only (TC-10),
/// Caramel Latte has the Figma defaults (TC-11), Americano has no default
/// size (TC-12) and its own Large price (TC-15), Latte is $3.00 with
/// Large +$1.00 (TC-14).
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
    _p(18, coffee, 'Latte', 3.00, 'Espresso with plenty of steamed milk'),
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

  // ---- Drink options (SA §3.5: option_groups, options,
  //      product_option_groups, product_options) ----

  static const _size = OptionGroup(
    id: 1,
    name: 'Size',
    selectionType: SelectionType.single,
    isRequired: true,
    maxSelect: 1,
  );
  static const _temperature = OptionGroup(
    id: 2,
    name: 'Temperature',
    selectionType: SelectionType.single,
    isRequired: true,
    maxSelect: 1,
  );
  static const _ice = OptionGroup(
    id: 3,
    name: 'Ice level',
    selectionType: SelectionType.single,
    isRequired: true,
    maxSelect: 1,
    needsIcedDrink: true,
    summaryNoun: 'ice',
  );
  static const _sweetness = OptionGroup(
    id: 4,
    name: 'Sweetness',
    selectionType: SelectionType.single,
    isRequired: true,
    maxSelect: 1,
    summaryNoun: 'sugar',
  );
  static const _addOns = OptionGroup(
    id: 5,
    name: 'Add-ons',
    selectionType: SelectionType.multiple,
    isRequired: false,
    maxSelect: 3,
  );

  static const small = 101, medium = 102, large = 103;
  static const hot = 201, iced = 202;
  static const noIce = 301, lessIce = 302, regularIce = 303, extraIce = 304;
  static const noSugar = 401, lessSugar = 402, normalSugar = 403;
  static const oatMilk = 501, extraShot = 502;

  /// Every option with its default extra price (`options.extra_price`).
  static final _options = <OptionGroup, List<DrinkOption>>{
    _size: [
      const DrinkOption(id: small, groupId: 1, name: 'Small'),
      DrinkOption(
        id: medium,
        groupId: 1,
        name: 'Medium',
        extraPrice: Money.dollars(0.5),
      ),
      DrinkOption(
        id: large,
        groupId: 1,
        name: 'Large',
        extraPrice: Money.dollars(1),
      ),
    ],
    _temperature: const [
      DrinkOption(id: hot, groupId: 2, name: 'Hot'),
      DrinkOption(id: iced, groupId: 2, name: 'Iced', isIced: true),
    ],
    _ice: const [
      DrinkOption(id: noIce, groupId: 3, name: 'No ice'),
      DrinkOption(id: lessIce, groupId: 3, name: 'Less'),
      DrinkOption(id: regularIce, groupId: 3, name: 'Regular'),
      DrinkOption(id: extraIce, groupId: 3, name: 'Extra'),
    ],
    _sweetness: const [
      // Words instead of percentages, short like the ice level names.
      // Cart lines add "sugar" (see OptionGroup.summaryNoun).
      DrinkOption(id: noSugar, groupId: 4, name: 'No sugar'),
      DrinkOption(id: lessSugar, groupId: 4, name: 'Less'),
      DrinkOption(id: normalSugar, groupId: 4, name: 'Regular'),
      DrinkOption(id: 404, groupId: 4, name: 'Extra'),
    ],
    _addOns: [
      DrinkOption(
        id: oatMilk,
        groupId: 5,
        name: 'Oat milk',
        extraPrice: Money.dollars(0.6),
      ),
      DrinkOption(
        id: extraShot,
        groupId: 5,
        name: 'Extra shot',
        extraPrice: Money.dollars(0.5),
      ),
      DrinkOption(
        id: 503,
        groupId: 5,
        name: 'Vanilla syrup',
        extraPrice: Money.dollars(0.4),
      ),
      DrinkOption(
        id: 504,
        groupId: 5,
        name: 'Caramel drizzle',
        extraPrice: Money.dollars(0.3),
      ),
      DrinkOption(
        id: 505,
        groupId: 5,
        name: 'Whipped cream',
        extraPrice: Money.dollars(0.4),
      ),
    ],
  };

  /// One `product_option_groups` row, plus any `product_options` rows:
  /// [only] limits the options this drink offers, [prices] replaces their
  /// extra price for this drink.
  static ProductOptionGroup _offer(
    OptionGroup group, {
    int? defaultId,
    List<int>? only,
    Map<int, double> prices = const {},
  }) => ProductOptionGroup(
    group: group,
    defaultOptionId: defaultId,
    options: [
      for (final o in _options[group]!)
        if (only == null || only.contains(o.id))
          prices.containsKey(o.id)
              ? DrinkOption(
                  id: o.id,
                  groupId: o.groupId,
                  name: o.name,
                  extraPrice: Money.dollars(prices[o.id]!),
                  isIced: o.isIced,
                )
              : o,
    ],
  );

  /// Hot or iced drinks: size, temperature, ice level, sweetness, add-ons.
  static List<ProductOptionGroup> _hotOrIced({
    int? size = medium,
    int temperature = hot,
    int ice = regularIce,
    int sweetness = normalSugar,
    Map<int, double> sizePrices = const {},
  }) => [
    _offer(_size, defaultId: size, prices: sizePrices),
    _offer(_temperature, defaultId: temperature),
    _offer(_ice, defaultId: ice),
    _offer(_sweetness, defaultId: sweetness),
    _offer(_addOns),
  ];

  /// Always-cold drinks: no temperature choice, ice level always shown.
  static List<ProductOptionGroup> _coldOnly() => [
    _offer(_size, defaultId: medium),
    _offer(_ice, defaultId: regularIce),
    _offer(_sweetness, defaultId: normalSugar),
    _offer(_addOns),
  ];

  static List<ProductOptionGroup> _groupsFor(int productId) =>
      switch (productId) {
        // TC-10: Espresso is hot only, so no ice level.
        1 => [
          _offer(_size, defaultId: medium),
          _offer(_temperature, defaultId: hot, only: [hot]),
          _offer(_sweetness, defaultId: noSugar),
          _offer(_addOns),
        ],
        // TC-12: no default size. TC-15: Large is +$0.50 for Americano.
        2 => _hotOrIced(
          size: null,
          sweetness: noSugar,
          sizePrices: {large: 0.5},
        ),
        // TC-11: the Figma defaults.
        4 => _hotOrIced(temperature: iced, ice: lessIce),
        // TC-14: Latte's own Large price.
        18 => _hotOrIced(sizePrices: {large: 1.0}),
        8 || 10 => _hotOrIced(temperature: iced),
        11 || 12 || 13 || 15 || 16 => _coldOnly(),
        _ => _hotOrIced(),
      };

  @override
  Future<ProductCustomization> fetchCustomization(int productId) async {
    await Future<void>.delayed(latency);
    final product = _products
        .where((p) => p.id == productId && p.isActive)
        .firstOrNull;
    if (product == null) throw StateError('No drink with id $productId');
    return ProductCustomization(
      product: product,
      groups: _groupsFor(productId),
    );
  }
}
