import 'package:flutter/material.dart';

import '../../data/models/user.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// The card at the top of the profile page (SA 2.0 §4.2.5.2).
///
/// A guest sees an invitation to log in; a customer sees the initials,
/// the name and whichever of email and phone number the account has
/// (FR-02 allows one of the two to be missing). Both open a page when
/// tapped: the login page for a guest, "Edit Personal Info" for a
/// customer, who also gets a pencil button for it.
class ProfileUserCard extends StatelessWidget {
  const ProfileUserCard({super.key, required this.user, required this.onTap});

  /// Null for a guest (FR-01: browsing without an account).
  final User? user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final user = this.user;
    final lines = user == null
        ? const ['Log in to place orders.']
        : [
            if (user.email != null) user.email!,
            if (user.phone != null) user.phone!,
          ];

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _Avatar(initials: user?.initials),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user?.fullName ?? 'Guest',
                      style: AppTextStyles.bodyMedium,
                    ),
                    for (final line in lines) ...[
                      const SizedBox(height: 2),
                      Text(line, style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
              if (user != null)
                IconButton(
                  onPressed: onTap,
                  tooltip: 'Edit profile',
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 20,
                    color: AppColors.mocha,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The round picture: the customer's initials, or a person for a guest.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});

  final String? initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.latte,
        shape: BoxShape.circle,
      ),
      child: initials == null
          ? const Icon(Icons.person, color: AppColors.mocha)
          : Text(
              initials!,
              style: AppTextStyles.sectionTitle.copyWith(
                color: AppColors.mocha,
              ),
            ),
    );
  }
}
