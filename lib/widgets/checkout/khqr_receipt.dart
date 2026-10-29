import 'package:flutter/material.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../data/models/order.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/time_format.dart';
import '../common/brand_mark.dart';

/// The picture saved by "Save QR to photos" (SA §4.2.3.3): the QR code
/// with the logo, the order, its drinks and when it was made and expires,
/// so a customer scrolling their photos can tell which order it was for.
///
/// Dates are written out in full ("Thu, 29 Oct 2026"), never "Today":
/// the picture is looked at later.
class KhqrReceipt extends StatelessWidget {
  const KhqrReceipt({super.key, required this.charge, required this.order});

  /// Logical width; saved at 3x (1080 px).
  static const width = 360.0;

  final KhqrCharge charge;
  final Order order;

  @override
  Widget build(BuildContext context) {
    final expires = formatClock(charge.expiresAt);
    return Container(
      width: width,
      color: AppColors.canvas,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BrandMark(size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('MOS Coffee', style: AppTextStyles.sectionTitle),
                    Text('KHQR payment', style: AppTextStyles.caption),
                  ],
                ),
              ),
              Text('Order #${order.id}', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 16),
          _Card(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: AppColors.espresso,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.qr_code_2,
                        color: AppColors.onBrand,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'KHQR',
                        style: AppTextStyles.sectionTitle.copyWith(
                          color: AppColors.onBrand,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    children: [
                      Text(charge.merchantName, style: AppTextStyles.caption),
                      const SizedBox(height: 2),
                      Text(
                        charge.amount.format(),
                        style: AppTextStyles.pageTitle,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: PrettyQrView.data(
                          data: charge.qrData,
                          decoration: const PrettyQrDecoration(
                            shape: PrettyQrSmoothSymbol(
                              color: AppColors.espresso,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.muted,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Expires at $expires',
                          style: AppTextStyles.label,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              children: [
                _Row(
                  'Created',
                  '${formatDate(order.createdAt)} · '
                      '${formatClock(order.createdAt)}',
                ),
                _Row('Pickup', _pickupText),
                const _Row('Pay with', 'ABA, ACLEDA or any Bakong app'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Order summary', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 8),
                for (final item in order.items) _ItemRow(item),
                const Divider(height: 20, color: AppColors.border),
                Row(
                  children: [
                    Expanded(
                      child: Text('Total', style: AppTextStyles.bodyMedium),
                    ),
                    Text(
                      order.totalAmount.format(),
                      style: AppTextStyles.sectionTitle,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'This code is for order #${order.id} only. '
            'Pay before $expires.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String get _pickupText {
    final time = order.pickupTime;
    if (order.pickupType == PickupType.asap || time == null) {
      return 'As soon as possible';
    }
    return '${formatDate(time)} · ${formatClock(time)}';
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: AppColors.surface,
        padding: padding,
        child: child,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: AppTextStyles.caption)),
          Expanded(
            child: Text(
              value,
              style: AppTextStyles.body,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow(this.item);

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.quantity} × ${item.productName}',
                  style: AppTextStyles.body,
                ),
                if (item.optionNames.isNotEmpty)
                  Text(
                    item.optionNames.join(' · '),
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(item.lineTotal.format(), style: AppTextStyles.body),
        ],
      ),
    );
  }
}
