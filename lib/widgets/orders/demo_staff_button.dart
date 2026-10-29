import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/orders/order_tracking_controller.dart';
import '../../data/mock/demo_staff.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// "Demo: staff" on the tracking page, only with the mock backend: does
/// what staff would do on the dashboard (confirm, prepare, mark ready,
/// complete, reject with a reason), so TC-24 to TC-27 can be shown
/// without a backend. Hidden when [demoStaffProvider] is null.
class DemoStaffButton extends ConsumerWidget {
  const DemoStaffButton({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(demoStaffProvider) == null || !order.isInProgress) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      onPressed: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.canvas,
        builder: (_) => _DemoStaffSheet(orderId: order.id),
      ),
      icon: const Icon(Icons.badge_outlined, size: 18),
      label: const Text('Demo: staff'),
      style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
    );
  }
}

class _DemoStaffSheet extends ConsumerStatefulWidget {
  const _DemoStaffSheet({required this.orderId});

  final int orderId;

  @override
  ConsumerState<_DemoStaffSheet> createState() => _DemoStaffSheetState();
}

class _DemoStaffSheetState extends ConsumerState<_DemoStaffSheet> {
  Future<void> _act(Order Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final tracking = ref.read(orderTrackingProvider(widget.orderId).notifier);
    try {
      action();
    } on OrderException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), persist: false),
      );
    }
    navigator.pop();
    await tracking.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(demoStaffProvider)!;
    final status = ref
        .watch(orderTrackingProvider(widget.orderId))
        .value
        ?.order
        .status;
    final next = switch (status) {
      OrderStatus.placed => 'Confirm order',
      OrderStatus.confirmed => 'Start preparing',
      OrderStatus.preparing => 'Mark ready',
      OrderStatus.ready => 'Picked up (complete)',
      _ => null,
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Demo: staff', style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text(
              'Mock backend only. Does what staff would do on the dashboard.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 16),
            if (next != null)
              FilledButton(
                onPressed: () => _act(() => staff.staffAdvance(widget.orderId)),
                child: Text(next),
              ),
            if (status == OrderStatus.placed) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    _act(() => staff.staffReject(widget.orderId, 'Sold out')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                child: const Text('Reject: Sold out'),
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Automatic staff', style: AppTextStyles.bodyMedium),
              subtitle: Text(
                'Moves orders along by itself every few seconds.',
                style: AppTextStyles.caption,
              ),
              value: !staff.staffPaused,
              onChanged: (on) => setState(() => staff.staffPaused = !on),
            ),
          ],
        ),
      ),
    );
  }
}
