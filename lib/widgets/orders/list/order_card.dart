import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/order.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/time_format.dart';
import 'order_status_badge.dart';

/// One order in the Orders tab (Figma: Order (History)).
///
/// Pickup code and status, when it was placed (and, while it is on its
/// way, when it is to be picked up), the drinks, and the total with
/// "Track order" or "Reorder" (FR-18, TC-28).
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.now,
    required this.onOpen,
    this.onReorder,
  });

  final Order order;

  /// "Now", so an order placed today says "Today" instead of its date.
  final DateTime now;

  /// Tapping the card, or "Track order", opens the order.
  final VoidCallback onOpen;

  /// Only for past orders.
  final VoidCallback? onReorder;

  DateTime get _placedAt => order.placedAt ?? order.createdAt;

  /// "Today · 10:12 AM · Pickup ASAP", "Oct 10 · 8:45 AM".
  String get _details {
    final at = _placedAt;
    final isToday =
        at.year == now.year && at.month == now.month && at.day == now.day;
    final day = isToday ? 'Today' : DateFormat('MMM d', 'en_US').format(at);
    final line = StringBuffer('$day · ${formatClock(at)}');
    if (order.isInProgress) {
      final pickupTime = order.pickupTime;
      if (order.pickupType == PickupType.scheduled && pickupTime != null) {
        line.write(' · Pickup ${formatClock(pickupTime)}');
      } else {
        line.write(' · Pickup ASAP');
      }
    }
    return line.toString();
  }

  /// "Cappuccino, Flat White, Espresso", with "×2" after a drink taken
  /// more than once.
  String get _drinks => [
    for (final item in order.items)
      item.quantity > 1
          ? '${item.productName} ×${item.quantity}'
          : item.productName,
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    final code = order.pickupCode;
    final onItsWay = order.isInProgress;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      code == null ? 'Order ${order.id}' : '#$code',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(_details, style: AppTextStyles.caption),
              const SizedBox(height: 6),
              Text(_drinks, style: AppTextStyles.body),
              const SizedBox(height: 8),
              const Divider(color: AppColors.border, height: 17),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.totalAmount.format(),
                      style: AppTextStyles.price,
                    ),
                  ),
                  if (onItsWay)
                    TextButton(
                      onPressed: onOpen,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.caramel,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Track order',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.caramel,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: onReorder,
                      icon: const Icon(Icons.replay, size: 18),
                      label: Text(
                        'Reorder',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.caramel,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.caramel,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
