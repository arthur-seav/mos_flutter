import 'package:flutter/material.dart';

import '../../../core/widgets/placeholder_page.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Orders',
      icon: Icons.receipt_long_outlined,
    );
  }
}
