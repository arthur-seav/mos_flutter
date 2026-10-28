import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// "+ Add more items" under the cart lines: a caramel dashed outline, as
/// in Figma (Cart with item). Flutter has no dashed border, so the outline
/// comes from the `dotted_border` package.
class AddMoreButton extends StatelessWidget {
  const AddMoreButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const _radius = 16.0;

  @override
  Widget build(BuildContext context) {
    return DottedBorder(
      options: const RoundedRectDottedBorderOptions(
        radius: Radius.circular(_radius),
        color: AppColors.caramel,
        strokeWidth: 1.5,
        dashPattern: [6, 4],
        padding: EdgeInsets.zero,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(_radius),
          onTap: onPressed,
          child: SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, size: 20, color: AppColors.caramel),
                const SizedBox(width: 8),
                Text(
                  'Add more items',
                  style: AppTextStyles.label.copyWith(color: AppColors.caramel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
