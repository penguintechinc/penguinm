import 'package:flutter/material.dart';
import '../theme/elder_colors.dart';

/// Color configuration for [SidebarMenu].
class SidebarColorConfig {
  /// Creates a [SidebarColorConfig].
  const SidebarColorConfig({
    this.sidebarBackground = ElderColors.slate800,
    this.sidebarBorder = ElderColors.slate700,
    this.categoryHeaderText = ElderColors.slate400,
    this.menuItemText = ElderColors.slate300,
    this.menuItemHover = ElderColors.slate700,
    this.menuItemActive = ElderColors.amber500,
    this.menuItemActiveText = ElderColors.white,
    this.scrollbarTrack = ElderColors.slate800,
    this.scrollbarThumb = ElderColors.slate600,
    this.scrollbarThumbHover = ElderColors.slate500,
    this.logoBackground = ElderColors.slate900,
    this.footerBackground = ElderColors.slate900,
    this.footerText = ElderColors.slate400,
  });

  /// Background color for the sidebar.
  final Color sidebarBackground;

  /// Border color separating the sidebar from content.
  final Color sidebarBorder;

  /// Text color for category headers.
  final Color categoryHeaderText;

  /// Text color for menu items in default state.
  final Color menuItemText;

  /// Background color for menu items on hover.
  final Color menuItemHover;

  /// Background color for the active menu item.
  final Color menuItemActive;

  /// Text color for active menu items.
  final Color menuItemActiveText;

  /// Background color for the scrollbar track.
  final Color scrollbarTrack;

  /// Color for the scrollbar thumb.
  final Color scrollbarThumb;

  /// Color for the scrollbar thumb on hover.
  final Color scrollbarThumbHover;

  /// Background color for the logo section at the top.
  final Color logoBackground;

  /// Background color for the footer section at the bottom.
  final Color footerBackground;

  /// Text color for content in the footer.
  final Color footerText;

  /// Default Elder dark theme configuration.
  static const SidebarColorConfig elder = SidebarColorConfig();
}
