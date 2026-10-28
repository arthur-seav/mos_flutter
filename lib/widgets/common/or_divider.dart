import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// A thin line with "or" in the middle, between two alternative actions
/// (login page, and later the sign-in panel at checkout).
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('or', style: AppTextStyles.caption),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}
