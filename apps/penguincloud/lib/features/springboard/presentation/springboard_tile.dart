import 'package:flutter/material.dart';

import '../domain/springboard_item.dart';

/// Maps a domain-layer [SpringboardIcon] to the Material icon
/// [SpringboardTile] renders — kept out of `domain/` so that layer stays
/// Flutter-free.
IconData materialIconFor(SpringboardIcon icon) => switch (icon) {
  SpringboardIcon.dashboard => Icons.dashboard,
  SpringboardIcon.people => Icons.people,
  SpringboardIcon.groups => Icons.groups,
  SpringboardIcon.settings => Icons.settings,
  SpringboardIcon.monitorHeart => Icons.monitor_heart,
  SpringboardIcon.article => Icons.article,
};

/// One tappable springboard tile: icon, title, optional description on a
/// themed card. Ported 1:1 from the legacy mobile app's `SpringboardTile`
/// — same layout and the same "tap invokes [onTap]" behaviour (the caller
/// decides what tapping does; see `SpringboardGrid`'s SnackBar).
class SpringboardTile extends StatelessWidget {
  /// Creates a tile for [item], invoking [onTap] when tapped.
  const SpringboardTile({required this.item, required this.onTap, super.key});

  /// The item this tile represents.
  final SpringboardItem item;

  /// Called when the tile is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(materialIconFor(item.icon), size: 40, color: colors.primary),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              if (item.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  item.description!,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
