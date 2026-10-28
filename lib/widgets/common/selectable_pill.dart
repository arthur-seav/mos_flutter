import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// A rounded choice button: dark when selected, white when not.
/// Used for category chips and drink options.
class SelectablePill extends StatelessWidget {
  const SelectablePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// False = faded and not tappable (e.g. add-ons once the limit is
  /// reached).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: selected ? AppColors.espresso : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: selected ? AppColors.espresso : AppColors.border,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: enabled ? onTap : null,
            // widthFactor: 1 keeps the pill as wide as its text. Without it,
            // the pill would fill the whole row inside a Wrap.
            child: SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: AppTextStyles.label.copyWith(
                      color: selected
                          ? AppColors.onBrand
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
