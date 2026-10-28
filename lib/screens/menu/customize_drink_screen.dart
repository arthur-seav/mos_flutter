import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/menu/drink_selection_controller.dart';
import '../../data/models/drink_selection.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/quantity_selector.dart';
import '../../widgets/common/square_icon_button.dart';
import '../../widgets/menu/option_group_section.dart';
import '../../widgets/menu/product_image.dart';

/// SA 2.0 §4.2.2.3 Product Customization (Figma: customizing Drinks).
///
/// Size, temperature, ice level, sweetness and add-ons (FR-08), with the
/// price updated on every tap (FR-09). The rules (BR-01 to BR-03) live in
/// [DrinkSelection]; this screen draws it and passes taps to
/// [DrinkSelectionController].
class CustomizeDrinkScreen extends ConsumerWidget {
  const CustomizeDrinkScreen({super.key, required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = drinkSelectionProvider(productId);
    final selection = ref.watch(provider);

    return Scaffold(
      body: Stack(
        children: [
          switch (selection) {
            AsyncData(:final value) => _Details(
              selection: value,
              productId: productId,
            ),
            AsyncError() => Center(
              child: EmptyState(
                icon: Icons.wifi_off_outlined,
                title: 'Could not load this drink',
                message: 'Check your connection and try again.',
                action: OutlinedButton(
                  onPressed: () => ref.invalidate(provider),
                  child: const Text('Try again'),
                ),
              ),
            ),
            _ => const Center(
              child: CircularProgressIndicator(color: AppColors.espresso),
            ),
          },
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 0, 0),
              child: SquareIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Back',
                onPressed: () => context.pop(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: selection.hasValue
          ? _AddToCartBar(
              selection: selection.requireValue,
              productId: productId,
            )
          : null,
    );
  }
}

/// Picture, name, price and the option groups.
class _Details extends ConsumerWidget {
  const _Details({required this.selection, required this.productId});

  final DrinkSelection selection;
  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = selection.customization.product;
    final controller = ref.read(drinkSelectionProvider(productId).notifier);
    final missing = selection.showMissing
        ? selection.missingRequired.map((g) => g.group.id).toSet()
        : const <int>{};

    void choose(group, option) {
      final message = controller.choose(group, option);
      if (message != null) _showMessage(context, message);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ProductImage(height: 290, radius: 0, iconSize: 96),
          // The content sheet overlaps the picture by its rounded corners.
          Transform.translate(
            offset: const Offset(0, -28),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              decoration: const BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(product.name, style: AppTextStyles.title),
                      ),
                      Text(
                        'from ${product.basePrice.format()}',
                        style: AppTextStyles.price,
                      ),
                    ],
                  ),
                  if (product.description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      product.description!,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  for (final group in selection.visibleGroups) ...[
                    const SizedBox(height: 24),
                    OptionGroupSection(
                      group: group,
                      isChosen: (option) => selection.isChosen(group, option),
                      canChoose: (option) => selection.canChoose(group, option),
                      onChoose: (option) => choose(group, option),
                      highlightMissing: missing.contains(group.group.id),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quantity and "Add to cart · $4.60" at the bottom.
class _AddToCartBar extends ConsumerWidget {
  const _AddToCartBar({required this.selection, required this.productId});

  final DrinkSelection selection;
  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(drinkSelectionProvider(productId).notifier);

    void addToCart() {
      final item = controller.addToCart();
      if (item == null) {
        _showMessage(
          context,
          DrinkSelectionController.missingMessage(
            ref.read(drinkSelectionProvider(productId)).requireValue,
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Added to cart · ${item.product.name}'
              '${item.options.isEmpty ? '' : ' · ${item.optionSummary}'}',
            ),
          ),
        );
      context.pop();
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Row(
            children: [
              QuantitySelector(
                quantity: selection.quantity,
                max: DrinkSelection.maxQuantity,
                onChanged: controller.setQuantity,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: addToCart,
                  child: Text('Add to cart · ${selection.total.format()}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
