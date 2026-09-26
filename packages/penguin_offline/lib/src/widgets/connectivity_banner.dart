import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity_status.dart';
import '../providers.dart';

/// Persistent banner shown above the app's content whenever
/// [connectivityProvider] reports [ConnectivityStatus.offline]; collapses
/// to nothing while online or before the first connectivity check
/// completes. Meant to sit above the router shell (spec §4.10), not to
/// wrap page content.
class ConnectivityBanner extends ConsumerWidget {
  /// Creates a connectivity banner reading [connectivityProvider].
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityProvider).value;
    if (status != ConnectivityStatus.offline) {
      return const SizedBox.shrink();
    }

    final colors = Theme.of(context).colorScheme;
    // Offline is an informational/warning state (not an error — nothing has
    // failed, writes just queue until reconnect), so this uses
    // `secondaryContainer`/`onSecondaryContainer` rather than the
    // error-tier pair `DeadLetterNotice` uses for an actual failed sync;
    // `tertiaryContainer` was considered but this theme's seed renders it
    // as a green/olive tone that reads as "success", the wrong semantic
    // for "offline" — `secondaryContainer`'s muted amber-brown fits
    // "warning" better. The `cloud_off` icon alone carries the state, so
    // no leading emoji/symbol duplicates it in the text.
    return Material(
      color: colors.secondaryContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off,
                color: colors.onSecondaryContainer,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Offline — changes will sync when you're back online",
                  style: TextStyle(color: colors.onSecondaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
