/// The distinct icon glyphs a springboard tile can render, kept as a plain
/// enum (rather than Flutter's `IconData`) so this file has no Flutter
/// dependency, per the app's domain-layer convention — `SpringboardTile`
/// maps each value to a concrete Material icon.
enum SpringboardIcon {
  /// The "Dashboard" destination's icon.
  dashboard,

  /// The "Users" destination's icon.
  people,

  /// The "Teams" destination's icon.
  groups,

  /// The "Settings" destination's icon.
  settings,

  /// The "Monitoring" destination's icon.
  monitorHeart,

  /// The "Logs" destination's icon.
  article,
}

/// One destination on the PenguinCloud springboard (home) screen: a
/// title, icon, target route, and the roles allowed to see it. Ported
/// from the legacy mobile app's `SpringboardItem` model, keeping the same
/// role-visibility rule — an item with no configured roles is visible to
/// every signed-in user.
class SpringboardItem {
  /// Creates a springboard item.
  const SpringboardItem({
    required this.id,
    required this.title,
    required this.icon,
    required this.route,
    this.description,
    this.roles = const [],
  });

  /// Stable identifier for this item, used as a `Key`/test target.
  final String id;

  /// Tile headline.
  final String title;

  /// Which icon to render for this tile.
  final SpringboardIcon icon;

  /// The destination path this tile represents (informational today — the
  /// legacy app never wired these to real routes either; tapping a tile
  /// shows a "Navigate to <title>" notice, per the ported behaviour).
  final String route;

  /// Optional one-line description shown under the title.
  final String? description;

  /// Roles allowed to see this item; empty means visible to everyone.
  final List<String> roles;

  /// True when this item should be shown to a user holding any of
  /// [userRoles] — an item with no configured [roles] is visible to
  /// everyone.
  bool isVisibleTo(List<String> userRoles) {
    if (roles.isEmpty) return true;
    return userRoles.any(roles.contains);
  }
}

/// PenguinCloud's fixed springboard destinations, ported 1:1 from the
/// legacy mobile app's `AppConstants.defaultItems`. This is static,
/// client-bundled content (no backend call), so the springboard always
/// renders — online or offline.
const List<SpringboardItem> springboardItems = [
  SpringboardItem(
    id: 'dashboard',
    title: 'Dashboard',
    icon: SpringboardIcon.dashboard,
    route: '/dashboard',
    description: 'System overview and metrics',
  ),
  SpringboardItem(
    id: 'users',
    title: 'Users',
    icon: SpringboardIcon.people,
    route: '/users',
    description: 'User management',
    roles: ['admin'],
  ),
  SpringboardItem(
    id: 'teams',
    title: 'Teams',
    icon: SpringboardIcon.groups,
    route: '/teams',
    description: 'Team management',
  ),
  SpringboardItem(
    id: 'settings',
    title: 'Settings',
    icon: SpringboardIcon.settings,
    route: '/settings',
    description: 'Application settings',
    roles: ['admin', 'maintainer'],
  ),
  SpringboardItem(
    id: 'monitoring',
    title: 'Monitoring',
    icon: SpringboardIcon.monitorHeart,
    route: '/monitoring',
    description: 'System health and metrics',
    roles: ['admin', 'maintainer'],
  ),
  SpringboardItem(
    id: 'logs',
    title: 'Logs',
    icon: SpringboardIcon.article,
    route: '/logs',
    description: 'Application logs',
    roles: ['admin', 'maintainer'],
  ),
];
