import 'package:flutter/material.dart';

/// SA 2.0 §4.2.3.3 KHQR. Placeholder until the page is built.
class KhqrPaymentScreen extends StatelessWidget {
  const KhqrPaymentScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Pay with KHQR')));
}
