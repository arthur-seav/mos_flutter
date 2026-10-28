import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/data/models/category.dart';
import 'package:mos_app/data/models/menu_catalog.dart';
import 'package:mos_app/data/models/money.dart';
import 'package:mos_app/data/models/product.dart';

void main() {
  group('Money', () {
    test('formats as US dollars', () {
      expect(Money.dollars(3.5).format(), r'$3.50');
      expect(const Money.cents(200).format(), r'$2.00');
    });

    test('adds without floating-point errors', () {
      expect(Money.dollars(0.1) + Money.dollars(0.2), Money.dollars(0.3));
      expect(Money.dollars(3.6) * 2, Money.dollars(7.2));
    });
  });

  group('MenuCatalog', () {
    const coffee = Category(id: 1, name: 'Coffee', sortOrder: 2);
    const tea = Category(id: 2, name: 'Tea', sortOrder: 1);
    const hidden = Category(id: 3, name: 'Old', sortOrder: 0, isActive: false);
    Product p(int id, int cat, String name, {bool active = true}) => Product(
      id: id,
      categoryId: cat,
      name: name,
      basePrice: Money.dollars(2),
      isActive: active,
    );

    final catalog = MenuCatalog(
      categories: const [coffee, tea, hidden],
      products: [
        p(1, 1, 'Caramel Latte'),
        p(2, 1, 'Espresso'),
        p(3, 2, 'Matcha Latte'),
        p(4, 1, 'Removed Latte', active: false),
        p(5, 3, 'Hidden drink'),
      ],
    );

    test('hides inactive categories and drinks, sorted by sort order', () {
      expect(catalog.categories.map((c) => c.name), ['Tea', 'Coffee']);
      expect(catalog.products.map((p) => p.id), [1, 2, 3, 5]);
    });

    test('"All" gives one section per category with drinks', () {
      final sections = catalog.sections();
      expect(sections.map((s) => s.category.name), ['Tea', 'Coffee']);
      expect(sections.last.products.map((p) => p.name), [
        'Caramel Latte',
        'Espresso',
      ]);
    });

    test('a category filter keeps only that section', () {
      final sections = catalog.sections(categoryId: 2);
      expect(sections.single.category.name, 'Tea');
    });

    test('TC-08: search matches names, ignoring case and spaces', () {
      final names = catalog
          .sections(query: '  LATTE ')
          .expand((s) => s.products)
          .map((p) => p.name);
      expect(names, ['Matcha Latte', 'Caramel Latte']);
    });

    test('TC-08: no match gives no sections', () {
      expect(catalog.sections(query: 'pizza'), isEmpty);
    });
  });

  group('MockMenuRepository', () {
    final repo = MockMenuRepository(latency: Duration.zero);

    test('TC-09: Mocha is sold out but still listed', () async {
      final menu = await repo.fetchMenu();
      final mocha = menu.products.firstWhere((p) => p.name == 'Mocha');
      expect(mocha.isSoldOut, isTrue);
    });

    test('inactive drinks never reach the app', () async {
      final menu = await repo.fetchMenu();
      expect(menu.products.any((p) => p.name == 'Seasonal Smoothie'), isFalse);
      final popular = await repo.fetchPopular();
      expect(popular.every((p) => p.isActive), isTrue);
    });

    test('popular drinks come most popular first', () async {
      final popular = await repo.fetchPopular(limit: 2);
      expect(popular.map((p) => p.name), ['Caramel Latte', 'Americano']);
    });
  });
}
