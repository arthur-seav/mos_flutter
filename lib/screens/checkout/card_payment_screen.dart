import 'package:flutter/material.dart';

/// SA 2.0 §4.2.3.3 Card. Placeholder until the page is built.
class CardPaymentScreen extends StatelessWidget {
  const CardPaymentScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Card Payment')));
}
