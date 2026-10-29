import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// A short notice that slides in at the top of the screen (Figma: Menu
/// with add item to cart, "Added to cart · Undo").
///
/// Shown in the app's root [Overlay], so it stays up when the page that
/// showed it closes. One at a time: a new toast replaces the old one.
/// It closes by itself after [duration], on its action, or when swiped up.
abstract final class TopToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) => showIn(
    Overlay.of(context, rootOverlay: true),
    title: title,
    message: message,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
  );

  /// For callers above the Navigator (the app-wide order alerts), which
  /// have no [BuildContext] with an [Overlay].
  static void showIn(
    OverlayState overlay, {
    required String title,
    String? message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    hide();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _TopToastView(
        title: title,
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
        duration: duration,
        onClosed: () => _remove(entry),
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  /// Takes the current toast away at once.
  static void hide() {
    final entry = _current;
    if (entry != null) _remove(entry);
  }

  static void _remove(OverlayEntry entry) {
    if (_current == entry) _current = null;
    // The overlay may already be gone (e.g. the app was closed).
    if (entry.mounted) entry.remove();
    entry.dispose();
  }
}

class _TopToastView extends StatefulWidget {
  const _TopToastView({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.duration,
    required this.onClosed,
  });

  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Duration duration;
  final VoidCallback onClosed;

  @override
  State<_TopToastView> createState() => _TopToastViewState();
}

class _TopToastViewState extends State<_TopToastView>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _animation.forward();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    await _animation.reverse();
    if (mounted) widget.onClosed();
  }

  @override
  void dispose() {
    // Cancelled here too, so no timer outlives the toast.
    _timer?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _animation, curve: Curves.easeOut);
    return Positioned(
      left: 16,
      right: 16,
      top: MediaQuery.paddingOf(context).top + 8,
      child: FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, -0.5),
            end: Offset.zero,
          ).animate(curve),
          child: GestureDetector(
            // Swipe up to close.
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < 0) _close();
            },
            child: Semantics(
              liveRegion: true,
              child: Material(
                color: AppColors.surface,
                elevation: 6,
                shadowColor: AppColors.espresso.withValues(alpha: 0.25),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 18,
                          color: AppColors.onBrand,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.title, style: AppTextStyles.label),
                            if (widget.message != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                widget.message!,
                                style: AppTextStyles.caption,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (widget.actionLabel != null)
                        TextButton(
                          onPressed: () {
                            widget.onAction?.call();
                            _close();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.caramel,
                          ),
                          child: Text(
                            widget.actionLabel!,
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.caramel,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
