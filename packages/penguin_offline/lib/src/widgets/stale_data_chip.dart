import 'package:flutter/material.dart';
import 'package:penguin_core/penguin_core.dart';

/// Small chip summarising how long ago cached data was fetched:
/// "just now" (< 1 minute), "`N`m ago" (< 1 hour), "`N`h ago" (< 1 day), or
/// "`N`d ago". [clock] is injectable so tests get deterministic ages
/// instead of depending on wall-clock time.
class StaleDataChip extends StatelessWidget {
  /// Creates a chip describing data fetched at [fetchedAt], relative to
  /// [clock] (defaults to the system clock).
  const StaleDataChip({
    required this.fetchedAt,
    this.clock = const SystemClock(),
    super.key,
  });

  /// When the underlying data was fetched from the server.
  final DateTime fetchedAt;

  /// Source of "now" when computing the age; overridable in tests.
  final Clock clock;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.schedule, size: 16),
      label: Text(
        'Last synced ${_formatAge(clock.now().difference(fetchedAt))}',
      ),
    );
  }

  /// Formats [age] as "just now" / "`N`m ago" / "`N`h ago" / "`N`d ago".
  static String _formatAge(Duration age) {
    if (age.inSeconds < 60) return 'just now';
    if (age.inMinutes < 60) return '${age.inMinutes}m ago';
    if (age.inHours < 24) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }
}
