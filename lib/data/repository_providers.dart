import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/auth_repository.dart';

/// The data sources the app uses (NFR-09).
///
/// Each provider is left empty on purpose: `main.dart` decides which
/// implementation to use (mock today, API later) with `overrides`, and
/// tests pass their own. Forgetting to choose one fails loudly at start-up.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError(
    'authRepositoryProvider must be overridden in main.dart',
  ),
);
