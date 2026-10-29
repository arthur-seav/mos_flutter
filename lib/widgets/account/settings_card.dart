import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A white rounded card that holds the profile's setting rows
/// (Figma: Customer Profile screen). A thin line separates the rows.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  /// One [SettingsRow] per entry, in the order they are shown.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.border,
              ),
            child,
          ],
        ],
      ),
    );
  }
}
