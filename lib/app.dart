import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/auth_controller.dart';
import 'router.dart';

class MosApp extends StatefulWidget {
  const MosApp({super.key, required this.authController});

  /// Passed in from `main.dart` so tests can give it a fake repository.
  final AuthController authController;

  @override
  State<MosApp> createState() => _MosAppState();
}

class _MosAppState extends State<MosApp> {
  // Created once, so rebuilds keep the navigation state.
  late final _router = AppRouter(widget.authController);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.authController,
      child: MaterialApp.router(
        title: 'MOS Coffee',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router.config,
      ),
    );
  }
}
