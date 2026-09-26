import 'package:flutter/material.dart';

/// A single menu item in the sidebar.
class MenuItem {
  /// Creates a [MenuItem].
  const MenuItem({
    required this.name,
    required this.href,
    this.icon,
    this.roles,
  });

  /// Display name of the menu item.
  final String name;

  /// Route or URL path the item links to.
  final String href;

  /// Optional icon to display before the name.
  final IconData? icon;

  /// Optional list of user roles permitted to see this item.
  final List<String>? roles;
}

/// A category of menu items, optionally collapsible.
class MenuCategory {
  /// Creates a [MenuCategory].
  const MenuCategory({
    this.header,
    this.collapsible = true,
    required this.items,
  });

  /// Optional header text displayed above the category.
  final String? header;

  /// Whether the category can be collapsed to hide its items.
  final bool collapsible;

  /// Menu items in this category.
  final List<MenuItem> items;
}
