import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'session.dart';

/// Persists authenticated sessions in flutter_secure_storage (encrypted on device).
/// Tokens are NEVER stored in plaintext (SharedPreferences, etc.).
class SessionStore {
  /// Creates a session store, optionally using a custom storage backend
  /// (for testing via [FlutterSecureStorage.setMockInitialValues]).
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const String _storageKey = 'penguin_auth_session';

  /// Loads the saved session, if any.
  Future<Session?> load() async {
    try {
      final json = await _storage.read(key: _storageKey);
      if (json == null) return null;

      final data = jsonDecode(json) as Map<String, dynamic>;
      return Session.fromJson(data);
    } catch (e) {
      // Storage error or corrupt data; treat as no session.
      return null;
    }
  }

  /// Saves a session to secure storage.
  Future<void> save(Session session) async {
    try {
      final json = jsonEncode(session.toJson());
      await _storage.write(key: _storageKey, value: json);
    } catch (e) {
      // Secure storage write failed; degrade gracefully — the session
      // stays valid in memory for the rest of this run, it just won't
      // survive a restart. AuthController surfaces persistence problems
      // via its own logging, not this low-level store.
    }
  }

  /// Clears the saved session from secure storage.
  Future<void> clear() async {
    try {
      await _storage.delete(key: _storageKey);
    } catch (e) {
      // Best-effort delete; nothing more to do if the platform rejects it.
    }
  }
}
