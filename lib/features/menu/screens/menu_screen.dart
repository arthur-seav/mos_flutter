import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/square_icon_button.dart';
import '../../../data/models/menu_catalog.dart';
import '../controllers/menu_filter_controller.dart';
import '../controllers/menu_providers.dart';
import '../widgets/add_button.dart';
import '../widgets/category_chips.dart';
import '../widgets/menu_search_field.dart';
import '../widgets/product_tile.dart';

/// SA 2.0 §4.2.2.2 Menu (Figma: Menu with empty cart).
///
/// Drinks by category (FR-06) with name, picture, description, price and
/// availability (FR-07), category chips and search (TC-08). Sold-out drinks
/// stay visible but cannot be added (TC-09).
/// (The cart bar from "Menu with add item to cart" comes with the cart.)
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    // Home may have opened search already; start from its text.
    _searchController = TextEditingController(
      text: ref.read(menuFilterProvider).query,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  MenuFilterController get _filter => ref.read(menuFilterProvider.notifier);

  void _closeSearch() {
    _searchController.clear();
    _filter.closeSearch();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(menuFilterProvider);
    final categories = ref.watch(menuCatalogProvider).value?.categories ?? [];
    final sections = ref.watch(menuSectionsProvider);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: filter.isSearching
                ? Row(
                    children: [
                      Expanded(
                        child: MenuSearchField(
                          controller: _searchController,
                          autofocus: true,
                          onChanged: _filter.setQuery,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SquareIconButton(
                        icon: Icons.close,
                        tooltip: 'Close search',
                        onPressed: _closeSearch,
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const Expanded(
                        child: Text('Menu', style: AppTextStyles.pageTitle),
                      ),
                      SquareIconButton(
                        icon: Icons.search,
                        tooltip: 'Search drinks',
                        onPressed: _filter.openSearch,
                      ),
                    ],
                  ),
          ),
          CategoryChips(
            categories: categories,
            selectedId: filter.categoryId,
            onSelected: _filter.selectCategory,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.espresso,
              onRefresh: () => ref.refresh(menuCatalogProvider.future),
              child: switch (sections) {
                AsyncData(:final value) when value.isEmpty => _Message(
                  child: EmptyState(
                    icon: Icons.search_off,
                    title: filter.query.trim().isEmpty
                        ? 'No drinks here yet'
                        : 'No drinks match "${filter.query.trim()}"',
                    message: 'Try another name or category.',
                  ),
                ),
                AsyncData(:final value) => _SectionList(sections: value),
                AsyncError() => _Message(
                  child: EmptyState(
                    icon: Icons.wifi_off_outlined,
                    title: 'Could not load the menu',
                    message: 'Check your connection and try again.',
                    action: OutlinedButton(
                      onPressed: () => ref.invalidate(menuCatalogProvider),
                      child: const Text('Try again'),
                    ),
                  ),
                ),
                _ => const Center(
                  child: CircularProgressIndicator(color: AppColors.espresso),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps a message scrollable, so pull-to-refresh still works on it.
class _Message extends StatelessWidget {
  const _Message({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(children: [child]);
}

class _SectionList extends StatelessWidget {
  const _SectionList({required this.sections});

  final List<MenuSection> sections;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    section.category.name,
                    style: AppTextStyles.sectionTitle,
                  ),
                ),
                Text(
                  '${section.products.length} '
                  '${section.products.length == 1 ? 'item' : 'items'}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          for (final product in section.products)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ProductTile(
                product: product,
                onAdd: () => showAddComingSoon(context, product),
              ),
            ),
        ],
      ],
    );
  }
}
