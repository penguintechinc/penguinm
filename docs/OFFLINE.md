# Offline Support

Apps cache data locally and queue writes for sync when reconnected. See each app's `README.md` for specific capabilities.

## Patterns

### Read Caching

Read-heavy features cache API responses in SQLite (`OfflineStore`). On reconnect, the app silently refreshes in the background.

- **UI**: display cached data with a "Last synced 2h ago" chip
- **No error UI** on stale data; show age transparently
- **Stale data age**: if unreachable for >7 days, warn the user

### Write Queuing (SyncQueue)

Writes (POST/PUT/PATCH) are queued locally when offline, sent in order on reconnect.

- **Idempotency**: all mutable requests include `Idempotency-Key` header
- **Retry**: exponential backoff (500ms → 4s max), max 5 attempts
- **Dead letters**: 4xx errors (other than 408/429) surface to the user; user decides to retry or discard
- **No retry**: 401/403 (auth errors); queued write is discarded, user signs in again

### Connectivity Indicator

Every app shows a `ConnectivityBanner` at the top:
- **Online**: hidden
- **Offline**: "⚠️ Offline — changes will sync when you're back online"

## Per-App Offline Support

### penguin_reference

| Feature | Reads | Writes | Notes |
|---|---|---|---|
| Springboard | ✅ cached | ✅ queued | List items updated silently on reconnect |
| Profile | ✅ cached | ✅ queued | User profile and settings synced |
| Settings | ✅ cached | ✅ queued | Theme, language, notifications queued |

**Flow**: user goes offline, updates profile, reconnects → changes sync with exponential backoff. If a write fails (4xx), dead-letter is surfaced.

### penguincloud

See `apps/penguincloud/README.md`.

### waddles

See `apps/waddles/README.md`.

### ruffled

See `apps/ruffled/README.md`.

### current

See `apps/current/README.md`.

### skauswatch

See `apps/skauswatch/README.md`.

### skauswatch_vault

See `apps/skauswatch_vault/README.md` (security-sensitive; offline write queueing for passkey syncs).

### elder

See `apps/elder/README.md`.

### elder_support

See `apps/elder_support/README.md`.

### nest_drive

See `apps/nest_drive/README.md` (document provider integration for background sync).

### tobogganing

See `apps/tobogganing/README.md`.

### tobogganing_connect

See `apps/tobogganing_connect/README.md` (VPN service; offline behavior differs).

### tobogganing_squawk

See `apps/tobogganing_squawk/README.md` (DNS service; offline behavior differs).

### waddleai_chat

See `apps/waddleai_chat/README.md`.

### gazer

See `apps/gazer/README.md` (Gazer Mobile v2; incoming).

## Implementation

### OfflineStore (SQLite)

```dart
class OfflineDatabase {
  // Schema: cache_entries(collection, id, json, fetched_at)
  //         pending_writes(id, method, path, body, idempotency_key, attempts, last_error)
}

abstract interface class OfflineStore {
  Future<void> put(String collection, String id, Map<String, Object?> data, {DateTime? fetchedAt});
  Future<CachedEntry?> get(String collection, String id);
  Future<List<CachedEntry>> list(String collection);
  Future<void> remove(String collection, String id);
  Future<void> clear(String collection);
}
```

### ConnectivityMonitor

```dart
enum ConnectivityStatus { online, offline, unknown }

class ConnectivityMonitor {
  Stream<ConnectivityStatus> get status;
  ConnectivityStatus get current;
  Future<void> start();
  Future<void> dispose();
}
```

### SyncQueue

```dart
class PendingWrite {
  final String id, method, path;
  final Map<String, Object?>? body;
  final String? idempotencyKey;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
}

class SyncQueue {
  Future<void> enqueue(PendingWrite w);
  Stream<int> get depth;
  Future<SyncReport> drain(); // called automatically on offline→online
  Stream<PendingWrite> get deadLetters; // 4xx ≠ 408/429 errors
}

class SyncReport {
  final int sent, failed, deadLettered;
}
```

### ConnectivityBanner Widget

```dart
class ConnectivityBanner extends ConsumerWidget {
  // Displays when status is offline
  // Hides when online
}
```

### Stale Data Indicator

```dart
class StaleDataChip extends StatelessWidget {
  const StaleDataChip({required DateTime fetchedAt});
  // Displays "Last synced 2h ago"
  // Age > 7 days → changes UI to warn
}
```

## Design for Offline

**Start with offline-first thinking:**

1. **What's the minimum read-only experience?** (core data cached and displayed)
2. **What writes make sense offline?** (queued, resync on reconnect)
3. **What requires real-time?** (not cached; grayed out or disabled offline)

**Example: Springboard (core app home)**

```dart
class SpringboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    final items = ref.watch(springboardItemsProvider);

    return Scaffold(
      body: connectivity.when(
        data: (status) => Scaffold(
          body: items.when(
            data: (data) => ListView(
              children: [
                if (status == ConnectivityStatus.offline)
                  const ConnectivityBanner(),
                ...data.map((item) => ListTile(
                  title: Text(item.name),
                  subtitle: status == ConnectivityStatus.offline
                    ? Text('Cached — Last synced ${item.cachedAt.age().humanize()}')
                    : null,
                )),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => ErrorView(failure: err),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => ErrorView(failure: err),
      ),
    );
  }
}
```

## Testing Offline

Use `FakeConnectivityMonitor` to simulate offline:

```dart
testWidgets('shows cached data while offline', (tester) async {
  final connectivity = FakeConnectivityMonitor()..setStatus(ConnectivityStatus.offline);

  await pumpPenguinApp(tester, manifest, overrides: [
    connectivityProvider.overrideWithValue(connectivity),
  ]);

  expect(find.text('Last synced'), findsWidgets);
  expect(find.byType(ConnectivityBanner), findsOneWidget);
});
```

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| Writes queued but never sent | SyncQueue not initialized on reconnect | Verify `ConnectivityMonitor.start()` called in bootstrap |
| Stale data UI never shows | `fetchedAt` not set when caching | Pass `DateTime.now()` to `OfflineStore.put` |
| Dead-letter never surfaces | Retry loop catching 4xx | Verify `SyncQueue.deadLetters` stream is wired to UI |
| "Last synced" chip shows wrong age | Clock not injected | Pass `Clock` to `StaleDataChip` or use `SystemClock` default |

See `packages/penguin_offline/` for full API and `packages/penguin_testing/` for fakes.
