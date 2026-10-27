import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// The cup logo and "MOS Coffee" at the top of the auth pages.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.espresso,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.coffee_outlined,
            color: AppColors.onBrand,
            size: 24,
          ),
        ),
        const SizedBox(width: 10),
        const Text('MOS Coffee', style: AppTextStyles.sectionTitle),
      ],
    );
  }
}
