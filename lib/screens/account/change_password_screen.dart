import 'package:flutter/material.dart';

import '../../widgets/common/placeholder_page.dart';

/// SA 2.0 §4.2.5.3 Change Password while signed in (FR-30). Placeholder until the page is built.
class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Change Password',
      icon: Icons.person_outline,
    );
  }
}
