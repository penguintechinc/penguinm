import 'package:flutter/material.dart';
import 'package:flutter_libs/flutter_libs.dart';
import 'form_factor.dart';
import 'navigation_destination_spec.dart';

/// A responsive scaffold that adapts navigation based on screen size.
///
/// Phone (< 600): NavigationBar at the bottom
/// Tablet (600-899): NavigationRail on the left
/// Expanded (≥ 900): SidebarMenu on the left + master/detail layout
class ResponsiveScaffold extends StatelessWidget {
  /// Creates a responsive scaffold with the given navigation and body.
  const ResponsiveScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.body,
    this.detail,
    this.appBar,
  });

  /// Navigation destinations; must be non-empty.
  final List<NavigationDestinationSpec> destinations;

  /// The index of the currently selected destination.
  final int selectedIndex;

  /// Callback invoked when a destination is selected.
  final ValueChanged<int> onSelect;

  /// The main body content.
  final Widget body;

  /// Optional detail pane for expanded form factor.
  final Widget? detail;

  /// Optional app bar to display above the scaffold.
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: appBar, body: _buildBody(context));
  }

  Widget _buildBody(BuildContext context) {
    final formFactor = FormFactor.of(context);
    return switch (formFactor) {
      FormFactor.phone => _buildPhoneLayout(context),
      FormFactor.tablet => _buildTabletLayout(context),
      FormFactor.expanded => _buildExpandedLayout(context),
    };
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelect,
        destinations: destinations
            .map(
              (d) => NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelect,
            labelType: NavigationRailLabelType.all,
            destinations: destinations
                .map(
                  (d) => NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
                )
                .toList(),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildExpandedLayout(BuildContext context) {
    // The tablet NavigationRail and phone NavigationBar both derive their
    // chrome color from the theme's ColorScheme (M3 defaults them to
    // `surfaceContainer`). SidebarMenu's own default colorConfig is a fixed
    // slate-blue palette unrelated to the app theme, which reads as a
    // second, mismatched surface for the same navigation chrome. Building
    // the sidebar's colors from this scaffold's ColorScheme — using the
    // same `surfaceContainer` token the rail/navbar already resolve to —
    // keeps all three form factors on one palette (spec: one UX design for
    // all apps).
    final colorScheme = Theme.of(context).colorScheme;
    final sidebarColors = SidebarColorConfig(
      sidebarBackground: colorScheme.surfaceContainer,
      sidebarBorder: colorScheme.outlineVariant,
      categoryHeaderText: colorScheme.onSurfaceVariant,
      menuItemText: colorScheme.onSurfaceVariant,
      menuItemHover: colorScheme.surfaceContainerHighest,
      menuItemActive: colorScheme.primary,
      // Not `onPrimary`: the active row's background is only a low-alpha
      // tint of `primary` over the dark surface (see SidebarMenu's
      // `_buildMenuItem`), not a solid `primary` fill — `onPrimary` is
      // tuned for contrast against a solid fill and reads as dim/illegible
      // here. `onSurface` stays legible against the actual (mostly-surface)
      // background, matching the original design's white active label.
      menuItemActiveText: colorScheme.onSurface,
      scrollbarTrack: colorScheme.surfaceContainer,
      scrollbarThumb: colorScheme.outline,
      scrollbarThumbHover: colorScheme.onSurfaceVariant,
      logoBackground: colorScheme.surfaceContainerHigh,
      footerBackground: colorScheme.surfaceContainerHigh,
      footerText: colorScheme.onSurfaceVariant,
    );

    final categories = [
      MenuCategory(
        collapsible: false,
        items: destinations
            .asMap()
            .entries
            .map(
              (e) => MenuItem(
                name: e.value.label,
                href: e.value.route,
                icon: e.value.icon,
              ),
            )
            .toList(),
      ),
    ];

    final List<Widget> detailPane;
    if (detail != null) {
      detailPane = [detail!];
    } else {
      detailPane = const <Widget>[];
    }

    final children = <Widget>[
      SidebarMenu(
        categories: categories,
        activePath: destinations[selectedIndex].route,
        onItemTap: (item) {
          final index = destinations.indexWhere((d) => d.route == item.href);
          if (index >= 0) onSelect(index);
        },
        colorConfig: sidebarColors,
      ),
      Expanded(child: body),
      ...detailPane,
    ];

    return Scaffold(body: Row(children: children));
  }
}
