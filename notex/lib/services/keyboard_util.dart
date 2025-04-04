import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Helper class for keyboard navigation and shortcuts
class KeyboardUtil {
  /// Wraps a widget with keyboard event handling for navigation
  /// Primarily used to handle the Escape key for back navigation
  static Widget wrapWithKeyboardHandler(BuildContext context, Widget child) {
    return Focus(
      autofocus: true,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        // Check for Escape key press
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          print('Escape key pressed - navigating back');
          // Attempt to navigate back
          Navigator.of(context).maybePop();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }

  /// Wraps a Scaffold with both keyboard navigation and back button handling
  static Widget wrapScaffoldWithBackButton(
    BuildContext context,
    Widget scaffold,
    VoidCallback? onBackPressed,
  ) {
    return WillPopScope(
      onWillPop: () async {
        if (onBackPressed != null) {
          onBackPressed();
          return false;
        }
        return true;
      },
      child: wrapWithKeyboardHandler(context, scaffold),
    );
  }

  /// Handles back navigation with custom logic
  static bool handleBackNavigation(BuildContext context) {
    // You can add custom logic here before navigating back
    Navigator.of(context).pop();
    return true;
  }
}
