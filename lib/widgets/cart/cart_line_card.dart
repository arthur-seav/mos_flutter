import 'package:flutter/material.dart';

import '../../data/models/cart_item.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../common/quantity_selector.dart';
import '../menu/product_image.dart';

/// One cart line (SA 2.0 §4.2.2.4, FR-10): picture, name, options, price
/// and quantity. Pure display; all logic stays in [CartController].
class CartLineCard extends StatelessWidget {
  const CartLineCard({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onQuantityChanged,
    required this.onEdit,
  });

  final CartItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductImage(
                imageUrl: item.product.imageUrl,
                width: 64,
                height: 64,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.product.name, style: AppTextStyles.sectionTitle),
                    const SizedBox(height: 2),
                    Text(item.optionSummary, style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: onEdit,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.caramel,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit options'),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: 'Remove ${item.product.name}',
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(item.lineTotal.format(), style: AppTextStyles.price),
              QuantitySelector(
                quantity: item.quantity,
                onChanged: onQuantityChanged,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
