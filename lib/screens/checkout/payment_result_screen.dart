import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app_routes.dart';
import '../../controllers/checkout/payment_outcome.dart';
import '../../data/models/order.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// SA 2.0 §4.2.3.4 Payment success / failed (TC-21, TC-22).
///
/// Success auto-redirects to Orders after 5 seconds unless the person
/// taps a button first. Back (system or app) never returns to the
/// payment page the outcome came from.
class PaymentResultScreen extends StatefulWidget {
  const PaymentResultScreen({super.key, required this.outcome});

  final PaymentOutcome outcome;

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> {
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    if (widget.outcome.isPaid) {
      _redirectTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) context.go(AppRoutes.orders);
      });
    }
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  /// Used by the success buttons: cancel the pending auto-redirect before
  /// navigating, so it cannot fire again on a disposed screen.
  void _goAndCancelTimer(String location) {
    _redirectTimer?.cancel();
    context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final outcome = widget.outcome;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: outcome.isPaid
              ? _SuccessView(outcome: outcome, onNavigate: _goAndCancelTimer)
              : _FailureView(outcome: outcome),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.outcome, required this.onNavigate});

  final PaymentOutcome outcome;
  final void Function(String location) onNavigate;

  @override
  Widget build(BuildContext context) {
    final order = outcome.order;
    final payment = outcome.payment;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const _ResultIcon(
                    outerColor: AppColors.successBg,
                    innerColor: AppColors.success,
                    icon: Icons.check,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment successful',
                    style: AppTextStyles.title,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${payment.amount.format()} paid via ${payment.method.label}. '
                    'Your order has been sent to the store.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _ResultCard(
                    rows: [
                      _ResultRow('Order', '#${order.pickupCode}'),
                      _ResultRow('Paid at', _formatTime(payment.paidAt)),
                      _ResultRow('Method', payment.method.label),
                      _ResultRow('Total', payment.amount.format()),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Text(
            'Taking you to your order...',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => onNavigate(AppRoutes.orders),
            child: const Text('Track my order'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => onNavigate(AppRoutes.home),
            child: const Text('Return to Home'),
          ),
        ],
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.outcome});

  final PaymentOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final order = outcome.order;
    final payment = outcome.payment;
    final reason = payment.failureReason ?? 'The payment did not go through.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const _ResultIcon(
                    outerColor: AppColors.muted,
                    innerColor: AppColors.danger,
                    icon: Icons.close,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment failed',
                    style: AppTextStyles.title,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$reason You have not been charged.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _ResultCard(
                    rows: [
                      _ResultRow('Amount', payment.amount.format()),
                      _ResultRow('Method', payment.method.label),
                      const _ResultRow('Status', 'Not charged'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          FilledButton(
            onPressed: () => context.pushReplacement(
              payment.method == PaymentMethod.khqr
                  ? AppRoutes.khqr(order.id)
                  : AppRoutes.card(order.id),
            ),
            child: const Text('Try again'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.pop(),
            child: const Text('Change payment method'),
          ),
        ],
      ),
    );
  }
}

/// The big circle icon at the top: a light outer ring behind a solid
/// inner circle with a white icon, as in the Figma success / failed pages.
class _ResultIcon extends StatelessWidget {
  const _ResultIcon({
    required this.outerColor,
    required this.innerColor,
    required this.icon,
  });

  final Color outerColor;
  final Color innerColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 120,
    height: 120,
    child: DecoratedBox(
      decoration: BoxDecoration(color: outerColor, shape: BoxShape.circle),
      child: Center(
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(color: innerColor, shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.onBrand, size: 36),
        ),
      ),
    ),
  );
}

/// The white card of label/value rows (order number, paid-at time, ...).
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.rows});

  final List<_ResultRow> rows;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(children: [for (final row in rows) row]),
  );
}

class _ResultRow extends StatelessWidget {
  const _ResultRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.bodyMedium),
      ],
    ),
  );
}

/// \"10:12 AM\", or \"--\" if the payment has no recorded time yet.
String _formatTime(DateTime? time) =>
    time == null ? '--' : DateFormat.jm().format(time);
