import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penguin_auth/penguin_auth.dart';

import '../domain/springboard_item.dart';
import 'springboard_tile.dart';

const double _tabletBreakpoint = 600;
const double _expandedBreakpoint = 900;
const double _gridSpacing = 16;
const double _tileAspectRatio = 1.1;

/// The current user's roles, read from the authenticated session's JWT
/// claims; empty (visible-to-everyone items only) when not authenticated.
List<String> _currentRoles(WidgetRef ref) {
  final state = ref.watch(authControllerProvider);
  return switch (state) {
    Authenticated(:final session) => session.claims.roles,
    _ => const [],
  };
}

/// Role-filtered, responsive grid of [springboardItems] — ported from the
/// legacy mobile app's `SpringboardGrid`: 2 columns on phone, 3 on tablet,
/// 4 on expanded widths, and tapping a tile shows a "Navigate to <title>"
/// [SnackBar] (the legacy app never wired these tiles to real routes
/// either — kept as-is per the migration brief).
class SpringboardGrid extends ConsumerWidget {
  /// Creates the springboard grid.
  const SpringboardGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = _currentRoles(ref);
    final items = springboardItems
        .where((item) => item.isVisibleTo(roles))
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= _expandedBreakpoint
            ? 4
            : constraints.maxWidth >= _tabletBreakpoint
            ? 3
            : 2;

        return GridView.builder(
          padding: const EdgeInsets.all(_gridSpacing),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: _gridSpacing,
            mainAxisSpacing: _gridSpacing,
            childAspectRatio: _tileAspectRatio,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return SpringboardTile(
              item: item,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Navigate to ${item.title}'),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
