import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../controllers/auth/auth_controller.dart';
import '../../controllers/common/submit_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/account/date_of_birth_field.dart';
import '../../widgets/common/error_banner.dart';
import '../../widgets/common/labeled_text_field.dart';
import '../../widgets/common/square_icon_button.dart';
import '../../widgets/common/top_toast.dart';

/// SA 2.0 §4.2.5.2 Edit Personal Info (Figma: Edit Profile).
///
/// A customer corrects their name, email, phone number and date of birth
/// (FR-04). The profile page shows the new details as soon as the save
/// succeeds (TC-07). A number that belongs to another account is refused
/// by the backend and shown here, with the form still filled in.
///
/// Figma names the first field "Nickname"; it holds the first and last
/// name of the account (`users.first_name` / `last_name`), so it is
/// labelled "Full name", as on the sign-up page.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen>
    with SubmitStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  DateTime? _dateOfBirth;

  @override
  void initState() {
    super.initState();
    // The form starts from the account as it is saved now.
    final user = ref.read(authControllerProvider).user;
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _dateOfBirth = user?.dateOfBirth;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String? _nullIfEmpty(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _pickDateOfBirth() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Date of Birth',
    );
    if (picked != null && mounted) setState(() => _dateOfBirth = picked);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final auth = ref.read(authControllerProvider.notifier);
    final ok = await runSubmit(
      () => auth.updateProfile(
        fullName: _nameController.text,
        email: _nullIfEmpty(_emailController),
        phone: _nullIfEmpty(_phoneController),
        dateOfBirth: _dateOfBirth,
      ),
    );
    if (!ok || !mounted) return;
    // The notice lives in the root overlay, so it stays up over the
    // profile page this one closes onto.
    TopToast.show(context, title: 'Profile saved.');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final error = submitError;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SquareIconButton(
                      icon: Icons.close,
                      tooltip: 'Cancel',
                      onPressed: isSubmitting ? null : () => context.pop(),
                    ),
                    const Expanded(
                      child: Text(
                        'Edit Personal Info',
                        style: AppTextStyles.title,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SquareIconButton(
                      icon: Icons.check,
                      tooltip: 'Save',
                      onPressed: isSubmitting ? null : _save,
                    ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  ErrorBanner(message: error),
                ],
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      LabeledTextField(
                        label: 'Full name',
                        hintText: 'Dara Sok',
                        controller: _nameController,
                        icon: Icons.person_outline,
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        validator: validateFullName,
                        onChanged: (_) => clearSubmitError(),
                        enabled: !isSubmitting,
                      ),
                      const SizedBox(height: 16),
                      LabeledTextField(
                        label: 'Email',
                        hintText: 'dara@example.com',
                        controller: _emailController,
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        // An account keeps at least one way to reach it
                        // (FR-02), so both cannot be emptied.
                        validator: (value) => validateSignUpEmail(
                          value,
                          phone: _phoneController.text,
                        ),
                        onChanged: (_) => clearSubmitError(),
                        enabled: !isSubmitting,
                      ),
                      const SizedBox(height: 16),
                      LabeledTextField(
                        label: 'Phone Number',
                        hintText: '012 345 678',
                        controller: _phoneController,
                        icon: Icons.phone_android_outlined,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.done,
                        validator: validateOptionalPhone,
                        onChanged: (_) => clearSubmitError(),
                        onFieldSubmitted: (_) => _save(),
                        enabled: !isSubmitting,
                      ),
                      const SizedBox(height: 16),
                      DateOfBirthField(
                        value: _dateOfBirth,
                        onPressed: _pickDateOfBirth,
                        enabled: !isSubmitting,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
