import 'package:flutter/material.dart';

import '../../widgets/common/placeholder_page.dart';

/// SA 2.0 §4.2.4 Order Tracking. Placeholder until the page is built.
class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final int orderId;

  @override
  Widget build(BuildContext context) {
    return PlaceholderPage(
      title: 'Order $orderId',
      icon: Icons.receipt_long_outlined,
    );
  }
}
