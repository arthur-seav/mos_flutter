import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../data/models/product.dart';

/// The dark "+" square on drink cards and rows. Sold-out drinks show a
/// "Sold out" tag instead, so they cannot be added (BR-05, TC-09).
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.product, required this.onAdd});

  final Product product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    if (product.isSoldOut) return const SoldOutTag();
    return Material(
      color: AppColors.espresso,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onAdd,
        child: Tooltip(
          message: 'Add ${product.name}',
          child: const SizedBox.square(
            dimension: 36,
            child: Icon(Icons.add, color: AppColors.onBrand, size: 22),
          ),
        ),
      ),
    );
  }
}

class SoldOutTag extends StatelessWidget {
  const SoldOutTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Sold out',
        style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

/// What "+" does for now. The next step (drink options) replaces this
/// with opening the customization page.
void showAddComingSoon(BuildContext context, Product product) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Choosing options for ${product.name} comes next.'),
      ),
    );
}
