import 'package:flutter/material.dart';

import '../../core/widgets/placeholder_page.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(title: 'Profile', icon: Icons.person_outline);
  }
}
