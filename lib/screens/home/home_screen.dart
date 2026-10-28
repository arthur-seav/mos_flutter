import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/square_icon_button.dart';
import '../../controllers/auth/auth_controller.dart';
import '../../controllers/menu/menu_filter_controller.dart';
import '../../controllers/menu/menu_providers.dart';
import '../../widgets/menu/add_button.dart';
import '../../widgets/menu/menu_search_field.dart';
import '../../widgets/menu/product_card.dart';
import '../../controllers/home/greeting.dart';

/// SA 2.0 §4.2.2.1 Home (Figma: Home, Home with Guest).
///
/// Greeting, cart button, drink search and "Popular now". The search box
/// opens the Menu tab with search ready; categories are on the Menu tab.
/// (The order status card from "Home screen with Order processing" comes
/// with order tracking.)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    final name = session.user?.firstName ?? 'Guest';
    final filter = ref.read(menuFilterProvider.notifier);

    void openMenu() => context.go(AppRoutes.menu);

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.espresso,
        onRefresh: () => ref.refresh(popularProductsProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              sliver: SliverList.list(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              greetingFor(DateTime.now()),
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(name, style: AppTextStyles.title),
                          ],
                        ),
                      ),
                      SquareIconButton(
                        icon: Icons.shopping_bag_outlined,
                        tooltip: 'Cart',
                        onPressed: () => _showCartComingSoon(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  MenuSearchField(
                    readOnly: true,
                    onTap: () {
                      filter.openSearch();
                      openMenu();
                    },
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Popular now',
                        style: AppTextStyles.sectionTitle,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        filter.selectCategory(null);
                        openMenu();
                      },
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),
            const _PopularGrid(),
          ],
        ),
      ),
    );
  }

  static void _showCartComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('The cart comes in a later step.')),
      );
  }
}

class _PopularGrid extends ConsumerWidget {
  const _PopularGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final popular = ref.watch(popularProductsProvider);

    return switch (popular) {
      AsyncData(:final value) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.92,
          ),
          itemCount: value.length,
          itemBuilder: (context, i) => ProductCard(
            product: value[i],
            onAdd: () => showAddComingSoon(context, value[i]),
          ),
        ),
      ),
      AsyncError() => SliverToBoxAdapter(
        child: EmptyState(
          icon: Icons.wifi_off_outlined,
          title: 'Could not load drinks',
          message: 'Check your connection and try again.',
          action: OutlinedButton(
            onPressed: () => ref.invalidate(popularProductsProvider),
            child: const Text('Try again'),
          ),
        ),
      ),
      _ => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(48),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.espresso),
          ),
        ),
      ),
    };
  }
}
