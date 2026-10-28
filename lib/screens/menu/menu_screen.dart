import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_routes.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/cart/cart_bar.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/square_icon_button.dart';
import '../../data/models/menu_catalog.dart';
import '../../controllers/cart/cart_controller.dart';
import '../../controllers/menu/menu_filter_controller.dart';
import '../../controllers/menu/menu_providers.dart';
import '../../widgets/menu/category_chips.dart';
import '../../widgets/menu/menu_search_field.dart';
import '../../widgets/menu/product_tile.dart';

/// Extra bottom padding under the menu list when the [CartBar] floats
/// over it, so the last item is never hidden behind the bar.
const _cartBarClearance = 76.0;

/// SA 2.0 §4.2.2.2 Menu (Figma: Menu with empty cart / Menu with add item
/// to cart).
///
/// Drinks by category (FR-06) with name, picture, description, price and
/// availability (FR-07), category chips and search (TC-08). Sold-out drinks
/// stay visible but cannot be added (TC-09). FR-10: a cart bar floats above
/// the bottom navigation while the cart has items, and opens the cart.
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
    final cartCount = ref.watch(cartCountProvider);
    final showCartBar = cartCount > 0;

    return SafeArea(
      child: Stack(
        children: [
          Column(
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
                    AsyncData(:final value) => _SectionList(
                      sections: value,
                      extraBottomPadding: showCartBar ? _cartBarClearance : 0,
                    ),
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
                      child: CircularProgressIndicator(
                        color: AppColors.espresso,
                      ),
                    ),
                  },
                ),
              ),
            ],
          ),
          if (showCartBar)
            Positioned(
              left: 16,
              right: 16,
              bottom: 8,
              child: CartBar(
                count: cartCount,
                total: ref.watch(cartTotalProvider),
                onTap: () => context.push(AppRoutes.cart),
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
  const _SectionList({required this.sections, this.extraBottomPadding = 0});

  final List<MenuSection> sections;

  /// Extra room at the bottom so the [CartBar] doesn't cover the last item.
  final double extraBottomPadding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + extraBottomPadding),
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
                onAdd: () => context.push(AppRoutes.product(product.id)),
              ),
            ),
        ],
      ],
    );
  }
}
