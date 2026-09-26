/// A single mobile app in the penguinm roster (design spec §1.1), giving
/// every manifest and sibling-app launcher a shared, compile-time-checked
/// reference instead of ad hoc string literals.
class KnownApp {
  /// Creates a roster entry; [applicationId] must equal
  /// `io.penguintech.<id>`.
  const KnownApp({
    required this.id,
    required this.displayName,
    required this.applicationId,
    required this.productKey,
    required this.family,
  });

  /// Directory/pubspec name in `apps/<id>` (snake_case).
  final String id;

  /// Human-readable app name shown in the UI and sibling-app launcher.
  final String displayName;

  /// Android application id, always `io.penguintech.<id>`.
  final String applicationId;

  /// Backend product this app talks to; scopes feature-flag keys.
  final String productKey;

  /// Product family this app belongs to for shared auth/tenant/SSO
  /// purposes (companion apps of one family share a browser session).
  final String family;
}

/// The complete, fixed roster of fourteen penguinm apps (design spec
/// §1.1) — the single source of truth for ids, product keys, and Android
/// application ids referenced by manifests and sibling-app entries.
class KnownApps {
  /// All fourteen roster apps, in design spec table order.
  static const List<KnownApp> all = [
    KnownApp(
      id: 'gazer',
      displayName: 'Gazer',
      applicationId: 'io.penguintech.gazer',
      productKey: 'waddlebot',
      family: 'Waddles',
    ),
    KnownApp(
      id: 'waddles',
      displayName: 'Waddles',
      applicationId: 'io.penguintech.waddles',
      productKey: 'waddlebot',
      family: 'Waddles',
    ),
    KnownApp(
      id: 'ruffled',
      displayName: 'Ruffled',
      applicationId: 'io.penguintech.ruffled',
      productKey: 'waddlebot',
      family: 'Waddles',
    ),
    KnownApp(
      id: 'current',
      displayName: 'Current',
      applicationId: 'io.penguintech.current',
      productKey: 'current',
      family: 'Current',
    ),
    KnownApp(
      id: 'skauswatch',
      displayName: 'SkausWatch',
      applicationId: 'io.penguintech.skauswatch',
      productKey: 'skauswatch',
      family: 'SkausWatch',
    ),
    KnownApp(
      id: 'skauswatch_vault',
      displayName: 'SkausWatch Vault',
      applicationId: 'io.penguintech.skauswatch_vault',
      productKey: 'skauswatch',
      family: 'SkausWatch',
    ),
    KnownApp(
      id: 'elder',
      displayName: 'Elder',
      applicationId: 'io.penguintech.elder',
      productKey: 'elder',
      family: 'Elder',
    ),
    KnownApp(
      id: 'elder_support',
      displayName: 'Elder Support',
      applicationId: 'io.penguintech.elder_support',
      productKey: 'elder',
      family: 'Elder',
    ),
    KnownApp(
      id: 'nest_drive',
      displayName: 'Nest Drive',
      applicationId: 'io.penguintech.nest_drive',
      productKey: 'nest',
      family: 'Nest',
    ),
    KnownApp(
      id: 'tobogganing',
      displayName: 'Tobogganing',
      applicationId: 'io.penguintech.tobogganing',
      productKey: 'tobogganing',
      family: 'Tobogganing',
    ),
    KnownApp(
      id: 'tobogganing_connect',
      displayName: 'Tobogganing Connect',
      applicationId: 'io.penguintech.tobogganing_connect',
      productKey: 'tobogganing',
      family: 'Tobogganing',
    ),
    KnownApp(
      id: 'tobogganing_squawk',
      displayName: 'Tobogganing Squawk',
      applicationId: 'io.penguintech.tobogganing_squawk',
      productKey: 'squawk',
      family: 'Tobogganing',
    ),
    KnownApp(
      id: 'penguincloud',
      displayName: 'PenguinCloud',
      applicationId: 'io.penguintech.penguincloud',
      productKey: 'penguincloud',
      family: 'PenguinCloud',
    ),
    KnownApp(
      id: 'waddleai_chat',
      displayName: 'WaddleAI Chat',
      applicationId: 'io.penguintech.waddleai_chat',
      productKey: 'waddleai',
      family: 'WaddleAI',
    ),
  ];

  /// Looks up a roster entry by [id]; returns null when not found.
  static KnownApp? byId(String id) {
    for (final app in all) {
      if (app.id == id) return app;
    }
    return null;
  }
}
