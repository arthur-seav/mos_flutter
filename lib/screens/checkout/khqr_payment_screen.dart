import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../app_routes.dart';
import '../../controllers/checkout/khqr_payment_controller.dart';
import '../../controllers/checkout/qr_saver.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/square_icon_button.dart';

/// SA 2.0 §4.2.3.3 KHQR payment (TC-21).
///
/// Shows the QR code for an order's KHQR charge, counts down to expiry
/// and reacts to [khqrPaymentProvider]: paid or failed moves on to the
/// result page, cancelled goes back to checkout.
class KhqrPaymentScreen extends ConsumerStatefulWidget {
  const KhqrPaymentScreen({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<KhqrPaymentScreen> createState() => _KhqrPaymentScreenState();
}

class _KhqrPaymentScreenState extends ConsumerState<KhqrPaymentScreen> {
  bool _saving = false;

  Future<void> _saveQr(String data, int orderId) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(qrSaverProvider).save(data, 'MOS-KHQR-$orderId');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('QR code saved to Photos.'),
            persist: false,
          ),
        );
    } on Object {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not save the QR code.'),
            persist: false,
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = khqrPaymentProvider(widget.orderId);
    final async = ref.watch(provider);

    ref.listen(provider, (previous, next) {
      final s = next.value;
      // Act once, when the stage changes, not on every countdown tick.
      if (s == null || s.stage == previous?.value?.stage) return;
      switch (s.stage) {
        case KhqrStage.paid:
        case KhqrStage.failed:
          context.pushReplacement(AppRoutes.paymentResult, extra: s.outcome);
        case KhqrStage.cancelled:
          context.pop();
        case KhqrStage.waiting:
          break;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Row(
                children: [
                  SquareIconButton(
                    icon: Icons.close,
                    tooltip: 'Cancel payment',
                    onPressed: () => ref.read(provider.notifier).cancel(),
                  ),
                  const SizedBox(width: 12),
                  Text('Pay with KHQR', style: AppTextStyles.title),
                ],
              ),
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Something went wrong.', style: AppTextStyles.body),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.pop(),
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                ),
                data: (state) => _KhqrBody(
                  state: state,
                  saving: _saving,
                  onSave: () => _saveQr(state.charge.qrData, widget.orderId),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KhqrBody extends ConsumerWidget {
  const _KhqrBody({
    required this.state,
    required this.saving,
    required this.onSave,
  });

  final KhqrState state;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final charge = state.charge;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              color: AppColors.surface,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: AppColors.espresso,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.qr_code_2,
                          color: AppColors.onBrand,
                          size: 20,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    child: Column(
                      children: [
                        Text(charge.merchantName, style: AppTextStyles.caption),
                        const SizedBox(height: 4),
                        Text(
                          charge.amount.format(),
                          style: AppTextStyles.pageTitle,
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 24),
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
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Expires in ${state.timeLeftText}',
                                style: AppTextStyles.label,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text('Waiting for payment...', style: AppTextStyles.bodyMedium),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Open your banking app, scan the code and confirm '
            '${charge.amount.format()}.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (!kIsWeb) ...[
            OutlinedButton(
              onPressed: saving ? null : onSave,
              child: const Text('Save QR to photos'),
            ),
            const SizedBox(height: 8),
          ],
          TextButton(
            onPressed: () =>
                ref.read(khqrPaymentProvider(charge.orderId).notifier).cancel(),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Cancel payment'),
          ),
        ],
      ),
    );
  }
}
