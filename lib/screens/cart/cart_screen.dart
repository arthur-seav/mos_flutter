import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_routes.dart';
import '../../controllers/auth/auth_controller.dart';
import '../../controllers/cart/cart_controller.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/money.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/cart/add_more_button.dart';
import '../../widgets/cart/cart_line_card.dart';
import '../../widgets/common/login_required_dialog.dart';
import '../../widgets/common/square_icon_button.dart';

/// SA 2.0 §4.2.2.4 Cart (FR-10, BR-05).
///
/// Shows every [CartItem] with its price and quantity, lets the customer
/// change quantities, remove lines or edit a line's options, and checks
/// for sold-out drinks (BR-05) before moving on to checkout. Guests are
/// asked to log in at "Go to checkout" (BR-06, TC-18).
class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _checking = false;

  /// BR-06 / TC-18: a guest logs in first, then comes back here and on to
  /// checkout, with the cart kept. Back on the login page, or "Not now",
  /// stays on the cart.
  Future<bool> _signedIn() async {
    if (ref.read(authControllerProvider).isCustomer) return true;
    if (!await askGuestToLogIn(context) || !mounted) return false;
    final ok = await context.push<bool>(
      AppRoutes.loginThenReturnTo(AppRoutes.checkout),
    );
    return ok == true && mounted;
  }

  Future<void> _goToCheckout() async {
    if (!await _signedIn()) return;
    setState(() => _checking = true);
    final notifier = ref.read(cartControllerProvider.notifier);
    final removed = await notifier.removeUnavailable();
    if (!mounted) return;
    setState(() => _checking = false);
    if (removed.isEmpty) {
      context.push(AppRoutes.checkout);
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(CartController.unavailableMessage(removed))),
      );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(cartControllerProvider);
    final isEmpty = items.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(count: ref.watch(cartCountProvider), isEmpty: isEmpty),
            Expanded(child: isEmpty ? const _EmptyCart() : const _CartList()),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isEmpty
                    ? () => context.go(AppRoutes.menu)
                    : (_checking ? null : _goToCheckout),
                child: Text(isEmpty ? 'Browse menu' : 'Go to checkout'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Back button, title and item count.
class _Header extends StatelessWidget {
  const _Header({required this.count, required this.isEmpty});

  final int count;
  final bool isEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          SquareIconButton(
            icon: Icons.chevron_left,
            tooltip: 'Back',
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: 12),
          // Figma: the same size as "Your cart is empty", smaller than tab titles.
          Expanded(child: Text('Your cart', style: AppTextStyles.title)),
          if (!isEmpty)
            Text(
              count == 1 ? '1 item' : '$count items',
              style: AppTextStyles.caption,
            ),
        ],
      ),
    );
  }
}

/// The lines, the "Add more items" button and the subtotal/total card.
class _CartList extends ConsumerWidget {
  const _CartList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartControllerProvider);
    final total = ref.watch(cartTotalProvider);
    final notifier = ref.read(cartControllerProvider.notifier);

    void removeLine(CartItem item) {
      final before = ref.read(cartControllerProvider);
      notifier.remove(item.lineId);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${item.product.name} removed'),
            duration: const Duration(seconds: 4),
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () => notifier.restore(before),
            ),
          ),
        );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items) ...[
            CartLineCard(
              item: item,
              onRemove: () => removeLine(item),
              onQuantityChanged: (q) => notifier.setQuantity(item.lineId, q),
              onEdit: () => context.push(
                AppRoutes.product(item.product.id, line: item.lineId),
              ),
            ),
            const SizedBox(height: 12),
          ],
          AddMoreButton(onPressed: () => context.go(AppRoutes.menu)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _SummaryRow(label: 'Subtotal', value: total, bold: false),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: AppColors.border),
                ),
                _SummaryRow(label: 'Total', value: total, bold: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.bold,
  });

  final String label;
  final Money value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? AppTextStyles.sectionTitle
        : AppTextStyles.body.copyWith(color: AppColors.textSecondary);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          value.format(),
          style: bold ? AppTextStyles.sectionTitle : AppTextStyles.body,
        ),
      ],
    );
  }
}

/// "Your cart is empty" (Figma: Cart - Empty).
class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: AppColors.latte,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 48,
                color: AppColors.mocha,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your cart is empty',
              style: AppTextStyles.title,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Pick a drink and we'll have it ready when you arrive.",
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
