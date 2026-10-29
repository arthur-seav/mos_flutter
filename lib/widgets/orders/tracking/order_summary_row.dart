import 'package:flutter/material.dart';

import '../../../data/models/order.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// "2 items · $8.10 · Paid with KHQR" with a chevron. Tapping it opens
/// the drinks and the total; it starts closed (Figma: the row at the
/// bottom of the tracking page).
class OrderSummaryRow extends StatefulWidget {
  const OrderSummaryRow({
    super.key,
    required this.order,
    required this.summary,
  });

  final Order order;

  /// [OrderProgress.summary].
  final String summary;

  @override
  State<OrderSummaryRow> createState() => _OrderSummaryRowState();
}

class _OrderSummaryRowState extends State<OrderSummaryRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.shopping_bag_outlined,
                    size: 20,
                    color: AppColors.mocha,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.summary, style: AppTextStyles.body),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.chevron_right,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                children: [
                  const Divider(height: 1, color: AppColors.border),
                  for (final item in widget.order.items)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.quantity} \u00d7 ${item.productName}',
                                  style: AppTextStyles.bodyMedium,
                                ),
                                if (item.optionNames.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.optionNames.join(' \u00b7 '),
                                    style: AppTextStyles.caption,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item.lineTotal.format(),
                            style: AppTextStyles.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total', style: AppTextStyles.sectionTitle),
                      Text(
                        widget.order.totalAmount.format(),
                        style: AppTextStyles.sectionTitle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
