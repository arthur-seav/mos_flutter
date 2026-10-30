import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The drink picture: the photo from the backend ([imageUrl]), cropped to
/// fill the box. Without a photo, while it loads, or when it cannot be
/// loaded, it is the Latte square with a cup, as in the Figma design.
/// Sold-out drinks are faded.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.radius = 14,
    this.iconSize = 32,
    this.dimmed = false,
  });

  final String? imageUrl;
  final double? width;
  final double? height;
  final double radius;
  final double iconSize;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final placeholder = Center(
      child: Icon(
        Icons.coffee_outlined,
        size: iconSize,
        color: AppColors.mocha,
      ),
    );
    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.latte,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: url == null || url.isEmpty
            ? placeholder
            : Image.network(
                url,
                fit: BoxFit.cover,
                width: width,
                height: height,
                // Decode at roughly the size it is drawn, not the full photo.
                cacheWidth: width != null && width!.isFinite
                    ? (width! * MediaQuery.devicePixelRatioOf(context)).round()
                    : null,
                frameBuilder: (context, child, frame, synchronous) =>
                    synchronous || frame != null ? child : placeholder,
                errorBuilder: (context, error, stack) => placeholder,
              ),
      ),
    );
  }
}
