import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'cached_flags.dart';

/// Persists the last successfully fetched [CachedFlags] snapshot in
/// `SharedPreferences` so [FeatureFlags.initialize] has an offline-safe
/// value before the first refresh completes. Flags are not secrets, so
/// `SharedPreferences` (not secure storage) is the correct store here.
class FlagCache {
  /// Creates a flag cache; pass a fake/mock [SharedPreferences] instance in
  /// tests, or omit to resolve the real one lazily on first use.
  FlagCache({this._prefs});

  static const _cacheKey = 'penguin_flags_cache';
  final SharedPreferences? _prefs;

  /// Loads the cached snapshot, or null when nothing has ever been cached
  /// or the stored value is corrupt JSON (treated the same as absent).
  Future<CachedFlags?> load() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    if (cached == null) return null;

    try {
      final json = jsonDecode(cached) as Map<String, Object?>;
      return CachedFlags.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Saves [cached] as the new persisted snapshot, overwriting any
  /// previous value.
  Future<void> save(CachedFlags cached) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final json = jsonEncode(cached.toJson());
    await prefs.setString(_cacheKey, json);
  }
}
