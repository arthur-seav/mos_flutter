import 'package:flutter/material.dart';

/// How every list in the app reacts when pulled past its end.
///
/// With Material 3, Android uses a "stretch" effect that scales the whole
/// list while you pull, which distorts cards and images. This turns that
/// effect off everywhere; lists simply stop at their ends.
/// Pull-to-refresh still works: it listens to the scroll, not to the effect.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
