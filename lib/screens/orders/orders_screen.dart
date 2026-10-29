import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_routes.dart';
import '../../controllers/auth/auth_controller.dart';
import '../../controllers/orders/my_orders_controller.dart';
import '../../controllers/orders/reorder.dart';
import '../../data/models/order.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/clock.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/top_toast.dart';
import '../../widgets/orders/list/order_card.dart';

/// SA 2.0 §4.2.5.1 Orders (Figma: Order (History) / Orders (empty)).
///
/// FR-18: the customer's orders, the ones on their way first, each with
/// its pickup code, status, time, drinks and total. "Track order" opens
/// the order; "Reorder" puts the same drinks back in the cart (TC-28).
/// Guests have no orders, so they are asked to log in first (BR-06).
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  /// TC-28: the same drinks at today's prices, minus whatever is no
  /// longer available; the notice says what happened.
  Future<void> _reorder(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) async {
    final result = await ref.read(reorderProvider)(order);
    if (!context.mounted) return;
    TopToast.show(context, title: result.message);
    if (result.added > 0) context.push(AppRoutes.cart);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(authControllerProvider).isGuest;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Text('Orders', style: AppTextStyles.pageTitle),
          ),
          Expanded(
            child: isGuest
                ? _LoginFirst(
                    onLogIn: () => context.push(
                      AppRoutes.loginThenReturnTo(AppRoutes.orders),
                    ),
                  )
                : _Orders(onReorder: (order) => _reorder(context, ref, order)),
          ),
        ],
      ),
    );
  }
}

/// A guest has no order history yet (BR-06).
class _LoginFirst extends StatelessWidget {
  const _LoginFirst({required this.onLogIn});

  final VoidCallback onLogIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyState(
        icon: Icons.person_outline,
        title: 'Log in to see your orders',
        message:
            'Your orders and their status show up here once you have an '
            'account.',
        action: FilledButton(onPressed: onLogIn, child: const Text('Log in')),
      ),
    );
  }
}

class _Orders extends ConsumerWidget {
  const _Orders({required this.onReorder});

  final void Function(Order order) onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);

    return switch (orders) {
      AsyncData(:final value) when value.isEmpty => const _NoOrdersYet(),
      AsyncData(:final value) => RefreshIndicator(
        color: AppColors.espresso,
        onRefresh: () => ref.read(myOrdersProvider.notifier).refresh(),
        child: _OrderList(
          orders: value,
          now: ref.watch(clockProvider)(),
          onOpen: (order) => context.push(AppRoutes.order(order.id)),
          onReorder: onReorder,
        ),
      ),
      AsyncError() => Center(
        child: EmptyState(
          icon: Icons.wifi_off_outlined,
          title: 'Could not load your orders',
          message: 'Check your connection and try again.',
          action: OutlinedButton(
            onPressed: () => ref.invalidate(myOrdersProvider),
            child: const Text('Try again'),
          ),
        ),
      ),
      _ => const Center(
        child: CircularProgressIndicator(color: AppColors.espresso),
      ),
    };
  }
}

/// Figma: Orders (empty). The Figma copy ("Order Not Found / It seem
/// likes you haven't process any order yet.") reads like an error and
/// has typos, so the page says this instead.
class _NoOrdersYet extends StatelessWidget {
  const _NoOrdersYet();

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
                Icons.receipt_long,
                size: 52,
                color: AppColors.espresso,
              ),
            ),
            const SizedBox(height: 24),
            const Text('No orders yet', style: AppTextStyles.title),
            const SizedBox(height: 8),
            Text(
              'Your orders will show up here.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.now,
    required this.onOpen,
    required this.onReorder,
  });

  final MyOrders orders;
  final DateTime now;
  final void Function(Order order) onOpen;
  final void Function(Order order) onReorder;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        if (orders.inProgress.isNotEmpty)
          ..._section('In progress', orders.inProgress, reorderable: false),
        if (orders.past.isNotEmpty)
          ..._section('Past orders', orders.past, reorderable: true),
      ],
    );
  }

  List<Widget> _section(
    String title,
    List<Order> orders, {
    required bool reorderable,
  }) => [
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: AppTextStyles.sectionTitle),
    ),
    for (final order in orders)
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: OrderCard(
          order: order,
          now: now,
          onOpen: () => onOpen(order),
          onReorder: reorderable ? () => onReorder(order) : null,
        ),
      ),
  ];
}
