import 'package:flutter/material.dart';

import '../../theme/app_text_styles.dart';
import '../common/brand_mark.dart';

/// The cup logo and "MOS Coffee" at the top of the auth pages.
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const BrandMark(),
        const SizedBox(width: 10),
        const Text('MOS Coffee', style: AppTextStyles.sectionTitle),
      ],
    );
  }
}
