import 'package:flutter/material.dart';

import '../../data/models/money.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// SA 2.0 §4.2.2.2 Menu (Figma: "Menu with add item to cart").
///
/// A floating bar that shows the current cart count and total, and opens
/// the cart (FR-10) when tapped. Pure display: the caller supplies [count]
/// and [total] (read from [cartCountProvider] / [cartTotalProvider]) and
/// [onTap]; this widget has no provider access of its own.
class CartBar extends StatelessWidget {
  const CartBar({
    super.key,
    required this.count,
    required this.total,
    required this.onTap,
  });

  final int count;
  final Money total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final itemsLabel = count == 1 ? '1 item' : '$count items';

    return Semantics(
      button: true,
      label: 'View cart',
      child: Material(
        color: AppColors.espresso,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.onBrand,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemsLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.onBrand.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        total.format(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.onBrand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'View cart',
                  style: AppTextStyles.label.copyWith(color: AppColors.onBrand),
                ),
                const Icon(Icons.chevron_right, color: AppColors.onBrand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
