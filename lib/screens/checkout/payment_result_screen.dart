import 'package:flutter/material.dart';

import '../../controllers/checkout/payment_outcome.dart';

/// SA 2.0 §4.2.3.4 Payment success / failed. Placeholder until built.
class PaymentResultScreen extends StatelessWidget {
  const PaymentResultScreen({super.key, required this.outcome});

  final PaymentOutcome outcome;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Text(outcome.isPaid ? 'Payment successful' : 'Payment failed'),
    ),
  );
}
