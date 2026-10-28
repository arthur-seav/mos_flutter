import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// A rounded choice button: dark when selected, white when not.
/// Used for category chips and drink options.
///
/// With a [subtitle] (a price), it is two lines tall and fills the width it
/// is given, for a row of equal buttons (size, shots).
class SelectablePill extends StatelessWidget {
  const SelectablePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final String label;

  /// Second, smaller line, e.g. "+$0.50".
  final String? subtitle;

  /// The text as one line: "Large +$0.50".
  String get fullLabel => subtitle == null ? label : '$label $subtitle';
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
            child: subtitle == null ? _oneLine() : _twoLines(),
          ),
        ),
      ),
    );
  }

  Color get _textColor => selected ? AppColors.onBrand : AppColors.textPrimary;

  Widget _oneLine() {
    // widthFactor: 1 keeps the pill as wide as its text. Without it,
    // the pill would fill the whole row inside a Wrap.
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(color: _textColor),
          ),
        ),
      ),
    );
  }

  Widget _twoLines() {
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.label.copyWith(color: _textColor),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              style: AppTextStyles.caption.copyWith(
                color: selected
                    ? AppColors.onBrand.withValues(alpha: 0.8)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
