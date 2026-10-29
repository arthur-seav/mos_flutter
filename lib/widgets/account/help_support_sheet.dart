import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/account/support_info.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// "Help & support" panel (Figma: overlay-support): the store's phone
/// number and today's opening hours, so a customer with a problem can
/// call and give their order number.
Future<void> showHelpSupportSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.canvas,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const HelpSupportSheet(),
    );

/// The contents of the help panel. Public so widget tests can show it
/// without a sheet around it.
class HelpSupportSheet extends ConsumerWidget {
  const HelpSupportSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(supportInfoProvider);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Help & Support', style: AppTextStyles.title),
            const SizedBox(height: 8),
            Text(
              'For a problem with an order, call the store and give your '
              'order number.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            info.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (error, stackTrace) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Could not load the store details.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(color: AppColors.danger),
                ),
              ),
              data: (support) => _DetailsCard(support: support),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.support});

  final SupportInfo support;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _DetailRow(label: 'Store Phone', value: support.phone),
          const SizedBox(height: 14),
          _DetailRow(label: 'Working Hours', value: support.hours),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.label),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
