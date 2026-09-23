import 'package:flutter/material.dart';

/// Navigation destination specification for use in ResponsiveScaffold.
///
/// Defines the route, label, icon, and selected icon for a navigation item.
class NavigationDestinationSpec {
  /// Creates a navigation destination specification.
  const NavigationDestinationSpec({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  /// The route path this destination navigates to.
  final String route;

  /// Human-readable label for this destination.
  final String label;

  /// Icon to display when not selected.
  final IconData icon;

  /// Icon to display when selected.
  final IconData selectedIcon;
}
