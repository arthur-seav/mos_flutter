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
    required this.onChoose,
    this.highlightMissing = false,
  });

  final ProductOptionGroup group;
  final bool Function(DrinkOption option) isChosen;
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
          Text('Choose up to ${g.maxSelect}.', style: AppTextStyles.caption),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in group.options)
              SelectablePill(
                label: option.label,
                selected: isChosen(option),
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
