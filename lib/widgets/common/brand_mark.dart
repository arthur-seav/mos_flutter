import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The MOS Coffee logo: a cup on an espresso square. Used on the auth
/// pages and on the saved KHQR image.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.espresso,
        borderRadius: BorderRadius.circular(size * 0.27),
      ),
      child: Icon(
        Icons.coffee_outlined,
        color: AppColors.onBrand,
        size: size * 0.55,
      ),
    );
  }
}
