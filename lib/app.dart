import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_scroll_behavior.dart';
import 'theme/app_theme.dart';
import 'router.dart';

class MosApp extends ConsumerWidget {
  const MosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'MOS Coffee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
