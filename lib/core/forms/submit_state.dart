import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository.dart';

/// Loading and error handling for a form's submit button.
///
/// The form calls [runSubmit] with the work to do. While it runs,
/// [isSubmitting] is true (show a spinner, disable inputs); if it throws,
/// [submitError] holds a message for the user. The state is an [AsyncValue],
/// Riverpod's type for "loading / data / error".
mixin SubmitStateMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  AsyncValue<void> _submitState = const AsyncData(null);

  bool get isSubmitting => _submitState.isLoading;

  String? get submitError {
    if (!_submitState.hasError) return null;
    final error = _submitState.error;
    // Expected failures carry their own message; anything else is a bug or
    // a network problem, so the user gets a generic one.
    return error is AuthException
        ? error.message
        : 'Something went wrong. Please try again.';
  }

  /// Returns true when [action] finished without throwing.
  Future<bool> runSubmit(Future<void> Function() action) async {
    if (isSubmitting) return false;
    setState(() => _submitState = const AsyncLoading());
    final result = await AsyncValue.guard(action);
    if (!mounted) return false;
    setState(() => _submitState = result);
    return !result.hasError;
  }

  /// Call when the user edits the form, so an old error does not linger.
  void clearSubmitError() {
    if (_submitState.hasError) {
      setState(() => _submitState = const AsyncData(null));
    }
  }
}
