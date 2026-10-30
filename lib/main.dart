import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/api/api_backend.dart';
import 'data/mock/mock_backend.dart';
import 'data/mock/mock_order_repository.dart';

void main() {
  runApp(
    ProviderScope(
      // NFR-09: choose the data sources here; nothing else changes.
      // Default: the Spring Boot backend shared with the store dashboard.
      // `--dart-define=MOS_BACKEND=mock` runs on the built-in demo data.
      overrides: useMockBackend
          ? MockBackend(
              staffTimings: const StaffTimings(),
              seedHistory: true,
            ).overrides
          : ApiBackend(baseUrl: apiBaseUrl()).overrides,
      child: const MosApp(),
    ),
  );
}
