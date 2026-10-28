import 'package:flutter/material.dart';

import '../../data/models/pickup_schedule.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/time_format.dart';

/// "Schedule pickup" (SA §4.2.3.2; Figma: overlay-schedule pickup).
///
/// Today's slots in a grid; slots that are too soon (BR-07) are faded.
/// Returns the confirmed time, or null when closed without confirming.
Future<DateTime?> showScheduleSheet(
  BuildContext context, {
  required PickupSchedule schedule,
  DateTime? initial,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => ScheduleSheet(schedule: schedule, initial: initial),
  );
}

class ScheduleSheet extends StatefulWidget {
  const ScheduleSheet({super.key, required this.schedule, this.initial});

  final PickupSchedule schedule;
  final DateTime? initial;

  @override
  State<ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<ScheduleSheet> {
  late DateTime? _picked =
      widget.initial != null && widget.schedule.allows(widget.initial!)
      ? widget.initial
      : null;

  @override
  Widget build(BuildContext context) {
    final schedule = widget.schedule;
    final slots = schedule.slots;
    final closes = schedule.closesAt;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Schedule pickup', style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text(
              closes == null
                  ? 'Today · The store is closed'
                  : 'Today · Store open until ${formatClock(closes)}',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (slots.every((s) => !s.isAvailable))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No more pickup times today.',
                  style: AppTextStyles.body,
                ),
              )
            else
              ConstrainedBox(
                // About four rows; the rest scrolls.
                constraints: const BoxConstraints(maxHeight: 220),
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.4,
                  children: [
                    for (final slot in slots)
                      _SlotButton(
                        slot: slot,
                        selected: slot.time == _picked,
                        onTap: () => setState(() => _picked = slot.time),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Slots must be at least '
                    '${schedule.store.settings.minPrepMin} minutes from now.',
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _picked == null
                    ? null
                    : () => Navigator.of(context).pop(_picked),
                child: Text(
                  _picked == null
                      ? 'Choose a time'
                      : 'Confirm ${formatClock(_picked!)}',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotButton extends StatelessWidget {
  const _SlotButton({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final PickupSlot slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = slot.isAvailable;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: selected
            ? AppColors.espresso
            : enabled
            ? AppColors.surface
            : AppColors.muted.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected
                ? AppColors.espresso
                : enabled
                ? AppColors.border
                : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: Center(
            child: Text(
              formatClock(slot.time),
              style: AppTextStyles.label.copyWith(
                color: selected
                    ? AppColors.onBrand
                    : enabled
                    ? AppColors.textPrimary
                    : AppColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
