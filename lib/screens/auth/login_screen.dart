import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app_routes.dart';

import '../../controllers/common/submit_state.dart';
import '../../utils/validators.dart';
import '../../widgets/common/error_banner.dart';
import '../../widgets/common/labeled_text_field.dart';
import '../../widgets/common/loading_button.dart';
import '../../widgets/common/or_divider.dart';
import '../../controllers/auth/auth_controller.dart';
import '../../widgets/auth/auth_back_button.dart';
import '../../widgets/auth/auth_footer_link.dart';
import '../../widgets/auth/auth_title.dart';
import '../../widgets/auth/brand_header.dart';

/// SA 2.0 §4.2.1.1 Login (Figma: 1.1_Login).
///
/// Customers sign in, or continue as a guest (FR-01, FR-03).
/// Where to go next is decided by the router: once [authControllerProvider]
/// has a session, the router leaves this page by itself.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.returnTo});

  /// For a guest sent here before ordering (BR-06, TC-18). After signing
  /// in, a pushed page pops with `true` so the caller (the cart) carries
  /// on; opened directly (a link to /checkout), it goes to [returnTo].
  /// The router's redirect does not run for a pushed page, so this page
  /// navigates itself.
  final String? returnTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SubmitStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    await runSubmit(
      () => ref
          .read(authControllerProvider.notifier)
          .signIn(
            identifier: _identifierController.text,
            password: _passwordController.text,
          ),
    );
    _leaveAfterSignIn();
  }

  /// See [LoginScreen.returnTo].
  void _leaveAfterSignIn() {
    final returnTo = widget.returnTo;
    if (returnTo == null ||
        !mounted ||
        !ref.read(authControllerProvider).isCustomer) {
      return;
    }
    context.canPop() ? context.pop(true) : context.go(returnTo);
  }

  /// A guest who creates an account here carries on like one who signs in.
  Future<void> _openSignUp() async {
    final created = await context.push<bool>(AppRoutes.signUp);
    if (created == true) _leaveAfterSignIn();
  }

  @override
  Widget build(BuildContext context) {
    final error = submitError;

    // A guest sent here to sign in before ordering (BR-06, TC-18) can go
    // back, and is already a guest.
    final isGuest = ref.watch(authControllerProvider).isGuest;

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                sliver: SliverList.list(
                  children: [
                    if (isGuest && context.canPop()) ...[
                      const AuthBackButton(),
                      const SizedBox(height: 16),
                    ],
                    const BrandHeader(),
                    const SizedBox(height: 32),
                    const AuthTitle(
                      title: 'Welcome back',
                      subtitle: 'Sign in to order ahead and skip the queue.',
                    ),
                    const SizedBox(height: 24),
                    AutofillGroup(
                      child: Column(
                        children: [
                          LabeledTextField(
                            label: 'Email',
                            hintText: 'Email or phone number',
                            controller: _identifierController,
                            icon: Icons.mail_outline,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.email,
                              AutofillHints.telephoneNumber,
                            ],
                            validator: validateEmailOrPhone,
                            onChanged: (_) => clearSubmitError(),
                            enabled: !isSubmitting,
                          ),
                          const SizedBox(height: 20),
                          LabeledTextField(
                            label: 'Password',
                            hintText: 'Password',
                            controller: _passwordController,
                            icon: Icons.lock_outline,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            validator: validateRequiredPassword,
                            onChanged: (_) => clearSubmitError(),
                            onFieldSubmitted: (_) => _signIn(),
                            enabled: !isSubmitting,
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton(
                          onPressed: isSubmitting
                              ? null
                              : () => context.push(AppRoutes.forgotPassword),
                          child: const Text('Forgot password?'),
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 8),
                      ErrorBanner(message: error),
                    ],
                    const SizedBox(height: 20),
                    LoadingButton(
                      label: 'Sign in',
                      isLoading: isSubmitting,
                      onPressed: _signIn,
                    ),
                    if (!isGuest) ...[
                      const SizedBox(height: 20),
                      const OrDivider(),
                      const SizedBox(height: 20),
                      OutlinedButton(
                        onPressed: isSubmitting
                            ? null
                            : ref
                                  .read(authControllerProvider.notifier)
                                  .continueAsGuest,
                        child: const Text('Continue as guest'),
                      ),
                    ],
                  ],
                ),
              ),
              // Keeps "New here?" at the bottom of tall screens, and below
              // the form when the keyboard is open.
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                    child: AuthFooterLink(
                      prompt: 'New here?',
                      action: 'Create an account',
                      onTap: isSubmitting ? null : _openSignUp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
