import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../data/models/product.dart';
import 'add_button.dart';
import 'product_image.dart';

/// A drink in the "Popular now" grid on Home.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onAdd});

  final Product product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ProductImage(
              imageUrl: product.imageUrl,
              width: double.infinity,
              iconSize: 40,
              dimmed: product.isSoldOut,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            product.name,
            style: AppTextStyles.sectionTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  product.basePrice.format(),
                  style: AppTextStyles.price,
                ),
              ),
              AddButton(product: product, onAdd: onAdd),
            ],
          ),
        ],
      ),
    );
    // Tapping the card opens the drink too, unless it is sold out.
    return GestureDetector(
      onTap: product.isSoldOut ? null : onAdd,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}
