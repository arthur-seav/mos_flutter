import 'package:flutter/material.dart';

import '../../widgets/common/placeholder_page.dart';

/// SA 2.0 §4.2.5.2 Edit Personal Info (FR-04, TC-07). Placeholder until the page is built.
class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Edit Personal Info',
      icon: Icons.person_outline,
    );
  }
}
