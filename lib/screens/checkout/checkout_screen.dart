import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_routes.dart';
import '../../controllers/cart/cart_controller.dart';
import '../../controllers/checkout/checkout_controller.dart';
import '../../data/models/cart_item.dart';
import '../../data/models/money.dart';
import '../../data/models/order.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/time_format.dart';
import '../../widgets/checkout/choice_card.dart';
import '../../widgets/checkout/schedule_sheet.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/square_icon_button.dart';

/// SA 2.0 §4.2.3.1 Checkout (Figma: Checkout).
///
/// Pickup time: as soon as possible or a slot today (FR-11, BR-07);
/// payment: KHQR or card (FR-13); a note; the order summary (FR-12); and
/// "Pay", which creates the order and opens the payment page. A guest is
/// asked to log in first (BR-06, TC-18); while online ordering is paused
/// the page says so and Pay is blocked (FR-41, TC-20).
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _paying = false;

  CheckoutController get _controller =>
      ref.read(checkoutControllerProvider.notifier);

  void _back() => context.canPop() ? context.pop() : context.go(AppRoutes.cart);

  Future<void> _schedule() async {
    final schedule = _controller.scheduleNow();
    final current = ref.read(checkoutControllerProvider).value?.pickupTime;
    final time = await showScheduleSheet(
      context,
      schedule: schedule,
      initial: current,
    );
    if (time == null || !mounted) return;
    if (!_controller.chooseSlot(time)) {
      _showMessage('That pickup time is no longer available. Choose another.');
    }
  }

  Future<void> _pay() async {
    setState(() => _paying = true);
    final result = await _controller.pay();
    if (!mounted) return;
    setState(() => _paying = false);
    switch (result) {
      case GoToPayment(:final order, :final method):
        context.push(
          method == PaymentMethod.card
              ? AppRoutes.card(order.id)
              : AppRoutes.khqr(order.id),
        );
      case CheckoutBlocked(needsLogin: true):
        await _askToLogIn();
      case CheckoutBlocked(:final message):
        _showMessage(message);
        if (ref.read(cartControllerProvider).isEmpty) _back();
    }
  }

  /// TC-18: the cart is kept; after logging in the customer comes back
  /// here.
  Future<void> _askToLogIn() async {
    final logIn = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log in to order'),
        content: const Text(
          'Guests can browse, but you need an account to place an order. '
          'Your cart will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log in'),
          ),
        ],
      ),
    );
    if (logIn == true && mounted) {
      context.push(AppRoutes.loginThenReturnTo(AppRoutes.checkout));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final checkout = ref.watch(checkoutControllerProvider);
    final lines = ref.watch(cartControllerProvider);
    final total = ref.watch(cartTotalProvider);
    final state = checkout.value;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  SquareIconButton(
                    icon: Icons.chevron_left,
                    tooltip: 'Back',
                    onPressed: _back,
                  ),
                  const SizedBox(width: 12),
                  Text('Checkout', style: AppTextStyles.title),
                ],
              ),
            ),
            Expanded(
              child: switch (checkout) {
                AsyncData(:final value) => _Form(
                  state: value,
                  lines: lines,
                  total: total,
                  controller: _controller,
                  onSchedule: _schedule,
                ),
                AsyncError() => Center(
                  child: EmptyState(
                    icon: Icons.wifi_off_outlined,
                    title: 'Could not load checkout',
                    message: 'Check your connection and try again.',
                    action: OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(checkoutControllerProvider),
                      child: const Text('Try again'),
                    ),
                  ),
                ),
                _ => const Center(
                  child: CircularProgressIndicator(color: AppColors.espresso),
                ),
              },
            ),
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
                onPressed: state != null && state.canPay && !_paying
                    ? _pay
                    : null,
                child: _paying
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.onBrand,
                        ),
                      )
                    : Text('Pay ${total.format()}'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.state,
    required this.lines,
    required this.total,
    required this.controller,
    required this.onSchedule,
  });

  final CheckoutState state;
  final List<CartItem> lines;
  final Money total;
  final CheckoutController controller;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final schedule = state.schedule;
    final settings = state.store.settings;
    final closes = schedule.closesAt;
    final scheduled = state.pickupType == PickupType.scheduled;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.isPaused) ...[
            const _PausedBanner(),
            const SizedBox(height: 16),
          ],
          const _Heading('Pickup at'),
          _StoreCard(
            name: settings.storeName,
            hours: closes == null
                ? 'Closed today'
                : schedule.isOpenNow
                ? 'Open until ${formatClock(closes)}'
                : 'Opens at ${formatClock(schedule.opensAt!)}',
          ),
          const SizedBox(height: 20),
          const _Heading('Pickup time'),
          ChoiceCard(
            icon: Icons.schedule,
            title: 'As soon as possible',
            subtitle: schedule.canPickUpAsap
                ? 'Ready in about ${settings.asapPrepMin} min'
                : 'Not available: the store is closed',
            selected: !scheduled,
            enabled: schedule.canPickUpAsap,
            onTap: controller.chooseAsap,
          ),
          const SizedBox(height: 12),
          ChoiceCard(
            icon: Icons.event_outlined,
            title: 'Schedule for later',
            subtitle: switch (state.pickupTime) {
              final time? when scheduled =>
                'Today at ${formatClock(time)} · Change',
              _ when schedule.canSchedule => 'Choose a pickup time today',
              _ => 'No more pickup times today',
            },
            selected: scheduled,
            enabled: schedule.canSchedule,
            onTap: onSchedule,
          ),
          const SizedBox(height: 20),
          const _Heading('Payment'),
          ChoiceCard(
            icon: Icons.qr_code_2,
            title: 'KHQR',
            subtitle: 'Scan with ABA, ACLEDA or any Bakong app',
            selected: state.paymentMethod == PaymentMethod.khqr,
            onTap: () => controller.choosePaymentMethod(PaymentMethod.khqr),
          ),
          const SizedBox(height: 12),
          ChoiceCard(
            icon: Icons.credit_card,
            title: 'Credit / Debit card',
            subtitle: 'Visa · Mastercard',
            selected: state.paymentMethod == PaymentMethod.card,
            onTap: () => controller.choosePaymentMethod(PaymentMethod.card),
          ),
          const SizedBox(height: 20),
          const _Heading('Note for barista'),
          TextFormField(
            initialValue: state.note,
            onChanged: controller.setNote,
            maxLines: 3,
            minLines: 3,
            maxLength: maxNoteLength,
            decoration: const InputDecoration(
              hintText: 'Optional · e.g. less foam, please',
            ),
          ),
          const SizedBox(height: 12),
          const _Heading('Order summary'),
          _Summary(lines: lines, total: total),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: AppTextStyles.sectionTitle),
  );
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.name, required this.hours});

  final String name;
  final String hours;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.latte,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              size: 20,
              color: AppColors.mocha,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  'Pick up at the counter · $hours',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// TC-20: online ordering is paused.
class _PausedBanner extends StatelessWidget {
  const _PausedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_outline, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Online ordering is paused',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'The store is not taking new orders right now. '
                  'Please try again later.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.lines, required this.total});

  final List<CartItem> lines;
  final Money total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (final l in lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 32,
                  child: Text('${l.quantity}×', style: AppTextStyles.label),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.product.name, style: AppTextStyles.bodyMedium),
                      if (l.options.isNotEmpty)
                        Text(l.optionSummary, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                Text(l.lineTotal.format(), style: AppTextStyles.body),
              ],
            ),
            const SizedBox(height: 10),
          ],
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('Total', style: AppTextStyles.sectionTitle)),
              Text(total.format(), style: AppTextStyles.sectionTitle),
            ],
          ),
        ],
      ),
    );
  }
}
