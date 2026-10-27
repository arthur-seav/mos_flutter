import 'package:flutter/material.dart';

import 'app.dart';
import 'data/mock/mock_auth_repository.dart';
import 'features/auth/auth_controller.dart';

void main() {
  // Swap MockAuthRepository for the API version once the backend is ready
  // (NFR-09). Nothing else in the app needs to change.
  final authController = AuthController(MockAuthRepository());
  runApp(MosApp(authController: authController));
}
