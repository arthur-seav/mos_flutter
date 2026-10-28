import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_routes.dart';
import '../../controllers/checkout/card_payment_controller.dart';
import '../../data/models/saved_card.dart';
import '../../data/repositories/card_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/card_validators.dart';
import '../../utils/clock.dart';
import '../../widgets/common/labeled_text_field.dart';
import '../../widgets/common/loading_button.dart';
import '../../widgets/common/square_icon_button.dart';

/// SA 2.0 §4.2.3.3 Card: saved cards, adding a new card, and paying with
/// the selected one (TC-22 covers a declined card).
///
/// Gap: the controller has no order total, so the button says "Pay now"
/// instead of an amount like the Figma "Pay $7.00".
class CardPaymentScreen extends ConsumerWidget {
  const CardPaymentScreen({super.key, required this.orderId});

  final int orderId;

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(cardPaymentProvider(orderId).notifier);
    final outcome = await notifier.pay();
    if (outcome != null && context.mounted) {
      context.pushReplacement(AppRoutes.paymentResult, extra: outcome);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cardPaymentProvider(orderId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              canPay: async.value?.canPay ?? false,
              isPaying: async.value?.isPaying ?? false,
              onPay: () => _pay(context, ref),
            ),
            Expanded(
              child: switch (async) {
                AsyncData(:final value) => _Body(
                  orderId: orderId,
                  state: value,
                ),
                AsyncError(:final error) => Center(child: Text('$error')),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.canPay,
    required this.isPaying,
    required this.onPay,
  });

  final bool canPay;
  final bool isPaying;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      child: Row(
        children: [
          SquareIconButton(
            icon: Icons.close,
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Text(
              'Card Payment',
              textAlign: TextAlign.center,
              style: AppTextStyles.title,
            ),
          ),
          if (isPaying)
            const SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            )
          else
            SquareIconButton(
              icon: Icons.check,
              tooltip: 'Pay',
              onPressed: canPay ? onPay : null,
            ),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.orderId, required this.state});

  final int orderId;
  final CardPaymentState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = state.selectedCard;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 190,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                for (final card in state.cards)
                  _CardTile(
                    card: card,
                    selected: card.id == state.selectedCardId,
                    onTap: () => ref
                        .read(cardPaymentProvider(orderId).notifier)
                        .selectCard(card.id),
                  ),
                _AddCardTile(orderId: orderId),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (selected != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ReadOnlyField(
                    label: 'Card Number',
                    value: selected.maskedNumber,
                  ),
                  const SizedBox(height: 16),
                  _ReadOnlyField(
                    label: 'Holder Name',
                    value: selected.holderName ?? '',
                  ),
                  const SizedBox(height: 16),
                  _ReadOnlyField(label: 'Expire Date', value: selected.expiry),
                  const SizedBox(height: 32),
                  LoadingButton(
                    label: 'Pay now',
                    isLoading: state.isPaying,
                    onPressed: state.canPay
                        ? () => _payAndNavigate(context, ref)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _payAndNavigate(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(cardPaymentProvider(orderId).notifier);
    final outcome = await notifier.pay();
    if (outcome != null && context.mounted) {
      context.pushReplacement(AppRoutes.paymentResult, extra: outcome);
    }
  }
}

/// A read-only summary field, styled like [LabeledTextField] but not
/// editable (the value comes from the selected saved card).
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(value, style: AppTextStyles.body),
        ),
      ],
    );
  }
}

/// A saved card drawn as a mocha card (Figma "Card Information"); only the
/// last four digits are shown, never the full number.
class _CardTile extends StatelessWidget {
  const _CardTile({
    required this.card,
    required this.selected,
    required this.onTap,
  });

  final SavedCard card;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.mocha,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: AppColors.caramel, width: 2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.caramel,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                Text(
                  card.brand,
                  style: AppTextStyles.body.copyWith(color: AppColors.onBrand),
                ),
              ],
            ),
            const Spacer(),
            Text(
              card.maskedNumber,
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.onBrand,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  (card.holderName ?? '').toUpperCase(),
                  style: AppTextStyles.body.copyWith(color: AppColors.onBrand),
                ),
                Text(
                  card.expiry,
                  style: AppTextStyles.body.copyWith(color: AppColors.onBrand),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCardTile extends StatelessWidget {
  const _AddCardTile({required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _AddCardSheet(orderId: orderId),
      ),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.latte,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.caramel,
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: AppColors.mocha, size: 32),
            SizedBox(height: 8),
            Text('Add card', style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// The "add a new card" form (SA §4.2.3.3), shown as a modal bottom sheet.
class _AddCardSheet extends ConsumerStatefulWidget {
  const _AddCardSheet({required this.orderId});

  final int orderId;

  @override
  ConsumerState<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends ConsumerState<_AddCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl = TextEditingController();
  bool _submitting = false;
  String? _serverError;

  @override
  void dispose() {
    _numberCtrl.dispose();
    _holderCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _serverError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final expiry = parseExpiry(_expiryCtrl.text)!;
    setState(() => _submitting = true);
    try {
      await ref
          .read(cardPaymentProvider(widget.orderId).notifier)
          .addCard(
            NewCard(
              number: digitsOnly(_numberCtrl.text),
              holderName: _holderCtrl.text.trim(),
              expiryMonth: expiry.month,
              expiryYear: expiry.year,
              cvv: _cvvCtrl.text.trim(),
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } on CardException catch (e) {
      setState(() => _serverError = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(clockProvider)();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add card', style: AppTextStyles.title),
              const SizedBox(height: 16),
              LabeledTextField(
                label: 'Card Number',
                controller: _numberCtrl,
                icon: Icons.credit_card,
                hintText: '1234 5678 9012 3456',
                keyboardType: TextInputType.number,
                validator: validateCardNumber,
              ),
              const SizedBox(height: 16),
              LabeledTextField(
                label: 'Holder Name',
                controller: _holderCtrl,
                icon: Icons.person_outline,
                hintText: 'DARA SOK',
                validator: validateCardHolder,
              ),
              const SizedBox(height: 16),
              LabeledTextField(
                label: 'Expire Date',
                controller: _expiryCtrl,
                icon: Icons.calendar_today_outlined,
                hintText: 'MM/YY',
                keyboardType: TextInputType.number,
                validator: (v) => validateExpiry(v, now: now),
              ),
              const SizedBox(height: 16),
              LabeledTextField(
                label: 'CVV',
                controller: _cvvCtrl,
                icon: Icons.lock_outline,
                hintText: '123',
                obscureText: true,
                keyboardType: TextInputType.number,
                validator: validateCvv,
              ),
              if (_serverError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _serverError!,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              LoadingButton(
                label: 'Add card',
                isLoading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
