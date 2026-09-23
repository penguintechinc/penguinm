/// Four deterministic springboard (home-screen destination) fixtures, as
/// plain JSON maps mirroring the shape a `FeatureModule` destination list
/// renders from — usable directly as `OfflineStore`/`ScriptedHttpClient`
/// payload data without depending on any app's feature module types.
const List<Map<String, Object?>> springboardItemFixtures =
    <Map<String, Object?>>[
      <String, Object?>{
        'id': 'springboard-0001',
        'title': 'Home',
        'route': '/home',
        'icon': 'home',
        'flagKey': null,
      },
      <String, Object?>{
        'id': 'springboard-0002',
        'title': 'Communities',
        'route': '/communities',
        'icon': 'groups',
        'flagKey': 'waddlebot.communities',
      },
      <String, Object?>{
        'id': 'springboard-0003',
        'title': 'Chat',
        'route': '/chat',
        'icon': 'chat',
        'flagKey': 'waddlebot.chat',
      },
      <String, Object?>{
        'id': 'springboard-0004',
        'title': 'Settings',
        'route': '/settings',
        'icon': 'settings',
        'flagKey': null,
      },
    ];
