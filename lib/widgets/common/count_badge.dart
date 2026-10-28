import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A small caramel circular badge showing a count (the Home cart button).
///
/// Shows nothing for 0, and caps the text at "9+" for 10 and above so the
/// badge never grows with the number of digits.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final label = count > 9 ? '9+' : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: AppColors.caramel,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}
