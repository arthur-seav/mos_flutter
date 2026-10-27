import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_page.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Menu',
      icon: Icons.local_cafe_outlined,
    );
  }
}
