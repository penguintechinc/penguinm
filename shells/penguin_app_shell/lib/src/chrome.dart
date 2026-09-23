import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_libs/flutter_libs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_offline/penguin_offline.dart';
import 'package:penguin_update/penguin_update.dart';

import 'app_manifest.dart';

/// Shared chrome every penguinm app renders around its router outlet:
/// `ConnectivityBanner`, the offline sync dead-letter notice, `UpdatePrompt`,
/// and (non-prod only) `ConsoleVersion` — stacked above the routed content,
/// per spec §4.10.
class AppChrome extends ConsumerWidget {
  /// Creates the app chrome for [manifest], wrapping [child] (the router
  /// outlet).
  const AppChrome({required this.manifest, required this.child, super.key});

  /// The app manifest, for branding/version/environment.
  final AppManifest manifest;

  /// The routed content this chrome wraps.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNonProd = manifest.config.environment != PenguinEnvironment.prod;
    return Column(
      children: [
        const ConnectivityBanner(),
        const DeadLetterNotice(),
        _UpdatePromptSlot(manifest: manifest),
        if (isNonProd)
          ConsoleVersion(
            appName: manifest.appName,
            version: manifest.appVersion,
            environment: manifest.config.environment.name,
          ),
        Expanded(child: child),
      ],
    );
  }
}

/// Renders `UpdatePrompt` once `updateStatusProvider` resolves; renders
/// nothing while pending or on failure — a failed update check must never
/// block or clutter the app (spec §4.8: never throws).
class _UpdatePromptSlot extends ConsumerWidget {
  const _UpdatePromptSlot({required this.manifest});

  final AppManifest manifest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(updateStatusProvider).value;
    if (status == null) return const SizedBox.shrink();
    return UpdatePrompt(
      applicationId: manifest.applicationId ?? manifest.productKey,
      status: status,
    );
  }
}

/// Surfaces `SyncQueue`'s durable dead-letter backlog (spec §4.7: "surfaced
/// to the user, never silently dropped") — shows the startup backlog count
/// plus every newly dead-lettered write, with Retry/Dismiss actions wired
/// to `SyncQueue.retryDeadLetter`/`acknowledgeDeadLetter`.
class DeadLetterNotice extends ConsumerStatefulWidget {
  /// Creates the dead-letter notice.
  const DeadLetterNotice({super.key});

  @override
  ConsumerState<DeadLetterNotice> createState() => _DeadLetterNoticeState();
}

class _DeadLetterNoticeState extends ConsumerState<DeadLetterNotice> {
  List<PendingWrite> _backlog = const [];
  StreamSubscription<PendingWrite>? _subscription;

  @override
  void initState() {
    super.initState();
    final queue = ref.read(syncQueueProvider);
    unawaited(
      queue.deadLetterBacklog().then((backlog) {
        if (mounted) setState(() => _backlog = backlog);
      }),
    );
    _subscription = queue.deadLetters.listen((write) {
      if (mounted) setState(() => _backlog = [..._backlog, write]);
    });
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _resolve(
    String id,
    Future<void> Function(String id) action,
  ) async {
    await action(id);
    if (!mounted) return;
    setState(() => _backlog = _backlog.where((w) => w.id != id).toList());
  }

  @override
  Widget build(BuildContext context) {
    if (_backlog.isEmpty) return const SizedBox.shrink();
    final next = _backlog.first;
    final queue = ref.read(syncQueueProvider);
    final colors = Theme.of(context).colorScheme;
    // A dead-lettered write is a genuine error (data may be lost without
    // user action) — `errorContainer`/`onErrorContainer` is Material 3's
    // error-tier pair, contrast-designed by `ColorScheme.fromSeed`, and a
    // sync-specific icon distinguishes it from `ConnectivityBanner`'s
    // `cloud_off`, so the two banners are never visually interchangeable
    // when stacked together. The `TextButton`s default to `colorScheme
    // .primary` (unreadable on this background — not contrast-designed
    // against an arbitrary Material ancestor color), so a local
    // `TextButtonTheme` pins their foreground to `onErrorContainer` too.
    return Material(
      color: colors.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.sync_problem,
                color: colors.onErrorContainer,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _backlog.length == 1
                      ? "A change couldn't be saved"
                      : '${_backlog.length} changes couldn\'t be saved',
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
              TextButtonTheme(
                data: TextButtonThemeData(
                  style: TextButton.styleFrom(
                    foregroundColor: colors.onErrorContainer,
                  ),
                ),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () => _resolve(next.id, queue.retryDeadLetter),
                      child: const Text('Retry'),
                    ),
                    TextButton(
                      onPressed: () =>
                          _resolve(next.id, queue.acknowledgeDeadLetter),
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
