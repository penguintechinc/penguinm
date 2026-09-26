import 'package:penguin_flags/penguin_flags.dart';

/// In-memory [FlagCache] fake: [load]/[save] read and write a field instead
/// of `SharedPreferences`. Extends the real (concrete) [FlagCache] —
/// required since `FeatureFlags` is typed to it directly — overriding both
/// methods entirely; the inherited constructor still runs (storing a null
/// `SharedPreferences?` field), but since [load]/[save] never call `super`,
/// no `SharedPreferences` I/O is ever invoked.
class InMemoryFlagCache extends FlagCache {
  /// Creates a fake cache pre-populated with [initial] (defaults to
  /// nothing cached, matching a fresh install).
  InMemoryFlagCache({CachedFlags? initial}) : _stored = initial;

  CachedFlags? _stored;

  /// Number of times [save] has been called.
  int saveCallCount = 0;

  @override
  Future<CachedFlags?> load() async => _stored;

  @override
  Future<void> save(CachedFlags cached) async {
    _stored = cached;
    saveCallCount++;
  }
}
