import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mos_app/data/mock/mock_menu_repository.dart';
import 'package:mos_app/features/menu/controllers/menu_filter_controller.dart';
import 'package:mos_app/features/menu/controllers/menu_providers.dart';

import '../../../helpers.dart';

void main() {
  late ProviderContainer container;
  MenuFilterController filter() => container.read(menuFilterProvider.notifier);

  setUp(() {
    container = ProviderContainer.test(overrides: mockOverrides());
  });

  test('starts on "All" with no search', () {
    final state = container.read(menuFilterProvider);
    expect(state.categoryId, isNull);
    expect(state.query, '');
    expect(state.isSearching, isFalse);
  });

  test('opening search goes back to "All"', () {
    filter().selectCategory(MockMenuRepository.tea);
    filter().openSearch();
    final state = container.read(menuFilterProvider);
    expect(state.categoryId, isNull);
    expect(state.isSearching, isTrue);
  });

  test('closing search clears the text', () {
    filter().openSearch();
    filter().setQuery('latte');
    filter().closeSearch();
    expect(container.read(menuFilterProvider).query, '');
  });

  test('menu sections follow the filter', () async {
    await container.read(menuCatalogProvider.future);
    filter().selectCategory(MockMenuRepository.tea);
    final sections = container.read(menuSectionsProvider).requireValue;
    expect(sections.single.category.name, 'Tea');
  });
}
