import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/mock/mock_auth_repository.dart';
import 'data/repository_providers.dart';

void main() {
  runApp(
    ProviderScope(
      // NFR-09: choose the data sources here. Swap MockAuthRepository for
      // the API version once the backend is ready; nothing else changes.
      overrides: [
        authRepositoryProvider.overrideWithValue(MockAuthRepository()),
      ],
      child: const MosApp(),
    ),
  );
}
