import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../data/models/product.dart';
import 'add_button.dart';
import 'product_image.dart';

/// A drink row on the Menu page: picture, name, description, price and
/// the add button (FR-07).
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, required this.onAdd});

  final Product product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final soldOut = product.isSoldOut;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          ProductImage(width: 72, height: 72, dimmed: soldOut),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: soldOut ? AppColors.textSecondary : null,
                  ),
                ),
                if (product.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    product.description!,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  product.basePrice.format(),
                  style: AppTextStyles.price.copyWith(
                    color: soldOut ? AppColors.textSecondary : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AddButton(product: product, onAdd: onAdd),
        ],
      ),
    );
  }
}
