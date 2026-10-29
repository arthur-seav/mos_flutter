import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/mock/mock_backend.dart';
import 'data/mock/mock_order_repository.dart';

void main() {
  runApp(
    ProviderScope(
      // NFR-09: choose the data sources here. Swap the mock backend for
      // the API repositories once the backend is ready; nothing else
      // changes.
      overrides: MockBackend(
        staffTimings: const StaffTimings(),
        seedHistory: true,
      ).overrides,
      child: const MosApp(),
    ),
  );
}
