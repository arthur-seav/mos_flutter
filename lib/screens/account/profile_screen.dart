import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_text_styles.dart';
import '../../widgets/common/placeholder_page.dart';
import '../../controllers/auth/auth_controller.dart';

/// Placeholder until the Account step. For now it only shows who is signed
/// in and lets them sign out (FR-03), so the login flow can be tried again.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final who = auth.isGuest ? 'Guest' : auth.user?.fullName ?? '';

    return PlaceholderPage(
      title: 'Profile',
      icon: Icons.person_outline,
      children: [
        const SizedBox(height: 24),
        Text('Signed in as $who', style: AppTextStyles.bodyMedium),
        const SizedBox(height: 16),
        SizedBox(
          width: 200,
          child: OutlinedButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
            child: Text(auth.isGuest ? 'Back to sign in' : 'Sign out'),
          ),
        ),
      ],
    );
  }
}
