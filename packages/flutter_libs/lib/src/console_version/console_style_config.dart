import 'package:flutter/material.dart';
import '../theme/elder_colors.dart';

/// Style configuration for console version logging.
class ConsoleStyleConfig {
  /// Creates a [ConsoleStyleConfig].
  const ConsoleStyleConfig({
    this.primaryColor = ElderColors.amber500,
    this.secondaryColor = ElderColors.slate500,
    this.accentColor = ElderColors.amber400,
    this.backgroundColor = ElderColors.slate900,
    this.fontFamily = 'monospace',
  });

  /// Primary color for console output styling.
  final Color primaryColor;

  /// Secondary color for console output styling.
  final Color secondaryColor;

  /// Accent color for highlights in console output.
  final Color accentColor;

  /// Background color for the console display.
  final Color backgroundColor;

  /// Font family to use in console output.
  final String fontFamily;

  /// Default Elder theme style.
  static const ConsoleStyleConfig elder = ConsoleStyleConfig();
}
