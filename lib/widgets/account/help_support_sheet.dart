import 'package:flutter/material.dart';

/// "Help & support" panel (Figma: overlay-support): the store's phone
/// and today's opening hours. Placeholder until the panel is built.
Future<void> showHelpSupportSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const SizedBox(
        height: 200,
        child: Center(child: Text('Help & Support')),
      ),
    );
