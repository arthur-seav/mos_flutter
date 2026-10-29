import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_routes.dart';
import '../../controllers/account/notification_settings_controller.dart';
import '../../controllers/auth/auth_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/account/help_support_sheet.dart';
import '../../widgets/account/profile_user_card.dart';
import '../../widgets/account/settings_card.dart';
import '../../widgets/account/settings_row.dart';

/// SA 2.0 §4.2.5.2 Profile (Figma: Profile (Guest), Customer Profile).
///
/// The fourth tab. A customer sees their details (FR-03) and can open
/// "Edit Personal Info" (FR-04, TC-07), "Change Password" (FR-30), their
/// order history, the notifications switch (FR-16, FR-38) and help, and
/// can sign out. A guest (FR-01) only gets the switch and help, plus an
/// invitation to log in (BR-06).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// The app version in the footer, as in the Figma design.
  static const _version = 'MOS Coffee · v1.0.0';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final notifications = ref.watch(notificationsEnabledProvider);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Profile', style: AppTextStyles.pageTitle),
            const SizedBox(height: 16),
            ProfileUserCard(
              user: user,
              // A guest logs in first and comes straight back here.
              onTap: () => context.push(
                user == null
                    ? AppRoutes.loginThenReturnTo(AppRoutes.profile)
                    : AppRoutes.editProfile,
              ),
            ),
            const SizedBox(height: 16),
            SettingsCard(
              children: [
                // Only a signed-in customer has a password or orders.
                if (user != null) ...[
                  SettingsRow(
                    icon: Icons.lock_outline,
                    label: 'Change Password',
                    trailing: SettingsRow.chevron,
                    onTap: () => context.push(AppRoutes.changePassword),
                  ),
                  SettingsRow(
                    icon: Icons.receipt_long_outlined,
                    label: 'Order history',
                    trailing: SettingsRow.chevron,
                    // The orders tab, not a page on top of this one.
                    onTap: () => context.go(AppRoutes.orders),
                  ),
                ],
                SettingsRow(
                  icon: Icons.notifications_none,
                  label: 'Notifications',
                  trailing: Switch(
                    value: notifications.value ?? true,
                    onChanged: notifications.isLoading
                        ? null
                        : (value) => ref
                              .read(notificationsEnabledProvider.notifier)
                              .set(value),
                    activeThumbColor: AppColors.espresso,
                    activeTrackColor: AppColors.caramel,
                  ),
                ),
                SettingsRow(
                  icon: Icons.info_outline,
                  label: 'Help & support',
                  trailing: SettingsRow.chevron,
                  onTap: () => showHelpSupportSheet(context),
                ),
              ],
            ),
            if (user != null) ...[
              const SizedBox(height: 16),
              SettingsCard(
                children: [
                  SettingsRow(
                    icon: Icons.logout,
                    label: 'Sign out',
                    color: AppColors.danger,
                    // The router shows the login page once the session ends.
                    onTap: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            const Center(child: Text(_version, style: AppTextStyles.caption)),
          ],
        ),
      ),
    );
  }
}
