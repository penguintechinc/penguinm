import 'package:flutter/material.dart';
import 'package:flutter_libs/flutter_libs.dart';

/// PenguinTheme provides Material 3 themes for the entire penguinm app roster.
///
/// All fourteen apps share this single design system; per-app branding is
/// limited to displayName, logoAsset, and seed color via AppBrand. The theme
/// defaults to dark mode with a gold/amber accent and registers ElderThemeData
/// so flutter_libs widgets match.
class PenguinTheme {
  /// Creates the dark Material 3 theme with optional seed color override.
  ///
  /// Defaults to amber/gold seed (ElderColors.amber500) if no seed.
  static ThemeData dark({Color? seed}) {
    final seedColor = seed ?? ElderColors.amber500;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: ElderColors.slate950,
      extensions: const [ElderThemeData.dark],
    );
  }

  /// Creates the light Material 3 theme with optional seed color override.
  ///
  /// Defaults to amber/gold seed (ElderColors.amber500) if no seed.
  /// Registers a light-appropriate ElderThemeData extension built from the
  /// light ColorScheme (flutter_libs does not export a static light variant).
  static ThemeData light({Color? seed}) {
    final seedColor = seed ?? ElderColors.amber500;
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    // Build a light ElderThemeData from the light scheme.
    final lightTheme = ElderThemeData(
      pageBackground: scheme.surface,
      cardBackground: scheme.surfaceContainer,
      cardBorder: scheme.outlineVariant,
      titleText: scheme.primary,
      subtitleText: scheme.onSurfaceVariant,
      labelText: scheme.onSurface,
      bodyText: scheme.onSurface,
      inputBackground: scheme.surfaceContainerHigh,
      inputBorder: scheme.outline,
      inputFocusBorder: seedColor,
      inputText: scheme.onSurface,
      primaryButton: scheme.primary,
      primaryButtonHover: scheme.primaryContainer,
      primaryButtonText: scheme.onPrimary,
      secondaryButton: scheme.secondaryContainer,
      secondaryButtonBorder: scheme.secondary,
      errorText: scheme.error,
      successText: scheme.inverseSurface,
      linkText: scheme.primary,
      linkHoverText: scheme.primaryContainer,
      divider: scheme.outlineVariant,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      extensions: [lightTheme],
    );
  }
}
