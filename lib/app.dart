import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'router.dart';

class MosApp extends StatefulWidget {
  const MosApp({super.key});

  @override
  State<MosApp> createState() => _MosAppState();
}

class _MosAppState extends State<MosApp> {
  // Created once, so hot reload and rebuilds keep the navigation state.
  final _router = AppRouter();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MOS Coffee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router.config,
    );
  }
}
