import 'package:flutter/material.dart';

import '../../data/models/category.dart';
import '../common/selectable_pill.dart';

/// "All", "Coffee", "Tea"... in a row that scrolls sideways (FR-06).
class CategoryChips extends StatelessWidget {
  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;

  /// Null means "All" is selected.
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          SelectablePill(
            label: 'All',
            selected: selectedId == null,
            onTap: () => onSelected(null),
          ),
          for (final c in categories) ...[
            const SizedBox(width: 8),
            SelectablePill(
              label: c.name,
              selected: selectedId == c.id,
              onTap: () => onSelected(c.id),
            ),
          ],
        ],
      ),
    );
  }
}
