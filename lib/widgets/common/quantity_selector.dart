import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// "−  1  +" on the customization page and in the cart.
class QuantitySelector extends StatelessWidget {
  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.min = 1,
    this.max = 20,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            tooltip: 'Decrease quantity',
            dark: false,
            onPressed: quantity > min ? () => onChanged(quantity - 1) : null,
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
          ),
          _StepButton(
            icon: Icons.add,
            tooltip: 'Increase quantity',
            dark: true,
            onPressed: quantity < max ? () => onChanged(quantity + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.dark,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool dark;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: dark ? AppColors.espresso : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: 36,
            child: Icon(
              icon,
              size: 20,
              color: !enabled
                  ? AppColors.textSecondary.withValues(alpha: 0.4)
                  : dark
                  ? AppColors.onBrand
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
