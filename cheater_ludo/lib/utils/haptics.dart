import 'package:flutter/services.dart';

/// Centralized haptic feedback helper.
/// Use these throughout the app for consistent tactile feedback.
class Haptics {
  Haptics._();

  /// Light tap — buttons, toggles, minor actions.
  static void tap() => HapticFeedback.selectionClick();

  /// Medium impact — confirming actions (start game, navigate).
  static void medium() => HapticFeedback.lightImpact();

  /// Heavy impact — destructive or important actions.
  static void heavy() => HapticFeedback.mediumImpact();

  /// Selection tick — switching tabs, picking options.
  static void selection() => HapticFeedback.selectionClick();

  /// Success vibration pattern — winning, completing something.
  static void success() => HapticFeedback.lightImpact();
}
