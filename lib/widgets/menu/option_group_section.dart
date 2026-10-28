import 'package:flutter/material.dart';

import '../../data/models/drink_option.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/selectable_pill.dart';

/// One option group on the customization page: title, Required/Optional
/// tag, and its options as pills (Figma: customizing Drinks).
class OptionGroupSection extends StatelessWidget {
  const OptionGroupSection({
    super.key,
    required this.group,
    required this.isChosen,
    required this.labelOf,
    required this.priceOf,
    required this.pricesInRow,
    required this.canChoose,
    required this.onChoose,
    this.highlightMissing = false,
  });

  final ProductOptionGroup group;
  final bool Function(DrinkOption option) isChosen;

  /// The button text, e.g. "Large +$0.50" (see DrinkSelection.labelOf).
  final String Function(DrinkOption option) labelOf;

  /// Just the price part, or null (see DrinkSelection.priceOf).
  final String? Function(DrinkOption option) priceOf;

  /// Size and shots: one row of equal buttons with the price under the
  /// name, so a longer price never pushes an option to a second line.
  final bool pricesInRow;

  /// At most this many options fit in one row on a phone.
  static const maxInRow = 4;

  /// False for options that would go over the group's limit; they are
  /// shown faded and cannot be tapped (BR-02, TC-13).
  final bool Function(DrinkOption option) canChoose;
  final ValueChanged<DrinkOption> onChoose;

  /// TC-12: the group is required but empty after "Add to cart".
  final bool highlightMissing;

  @override
  Widget build(BuildContext context) {
    final g = group.group;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(g.name, style: AppTextStyles.sectionTitle)),
            _Tag(
              text: g.isRequired ? 'Required' : 'Optional',
              danger: highlightMissing,
            ),
          ],
        ),
        if (g.isMultiple) ...[
          const SizedBox(height: 4),
          Text(
            group.options.any((o) => !canChoose(o))
                ? 'You have chosen ${g.maxSelect}. Remove one to pick another.'
                : 'Choose up to ${g.maxSelect}.',
            style: AppTextStyles.caption,
          ),
        ],
        const SizedBox(height: 12),
        if (pricesInRow && group.options.length <= maxInRow)
          Row(
            children: [
              for (final (i, option) in group.options.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: SelectablePill(
                    label: option.name,
                    subtitle: priceOf(option),
                    selected: isChosen(option),
                    enabled: canChoose(option),
                    onTap: () => onChoose(option),
                  ),
                ),
              ],
            ],
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in group.options)
                SelectablePill(
                  label: labelOf(option),
                  selected: isChosen(option),
                  enabled: canChoose(option),
                  onTap: () => onChoose(option),
                ),
            ],
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.danger});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: danger
            ? AppColors.danger.withValues(alpha: 0.12)
            : AppColors.muted,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: danger ? AppColors.danger : AppColors.textSecondary,
          fontWeight: danger ? FontWeight.w600 : null,
        ),
      ),
    );
  }
}
