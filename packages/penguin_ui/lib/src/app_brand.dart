import 'package:flutter/material.dart';

/// App branding configuration for per-app customization.
///
/// Provides optional display name, logo asset, and seed color for the theme.
class AppBrand {
  /// Creates an app brand with optional display name, logo, and seed color.
  const AppBrand({this.displayName, this.logoAsset, this.seed});

  /// Optional app display name; overrides the default app name.
  final String? displayName;

  /// Optional path to a logo asset (typically `assets/images/logo.png`).
  final String? logoAsset;

  /// Optional seed color for Material 3 theme generation; overrides default gold.
  final Color? seed;
}
