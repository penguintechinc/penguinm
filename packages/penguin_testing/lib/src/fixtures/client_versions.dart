/// Four deterministic client-version fixtures, as plain JSON maps shaped
/// like `GET /api/v1/client/version` response bodies (the field names
/// `penguin_api`'s `ClientVersionInfo.fromJson` expects) — a raw map so
/// this package can stay independent of `penguin_api`; consumers that
/// already depend on it can call `ClientVersionInfo.fromJson` on these
/// directly.
const List<Map<String, Object?>> clientVersionFixtures = <Map<String, Object?>>[
  <String, Object?>{
    'id': 'clientversion-0001',
    'latestVersion': '1.0.0',
    'minimumVersion': null,
    'storeUrl': null,
    'releaseNotes': 'Initial release.',
  },
  <String, Object?>{
    'id': 'clientversion-0002',
    'latestVersion': '1.2.0',
    'minimumVersion': '1.0.0',
    'storeUrl':
        'https://play.google.com/store/apps/details?id=io.penguintech.example',
    'releaseNotes': 'Adds offline sync.',
  },
  <String, Object?>{
    'id': 'clientversion-0003',
    'latestVersion': '2.0.0',
    'minimumVersion': '1.5.0',
    'storeUrl':
        'https://play.google.com/store/apps/details?id=io.penguintech.example',
    'releaseNotes': 'Breaking API changes — update required.',
  },
  <String, Object?>{
    'id': 'clientversion-0004',
    'latestVersion': '2.0.0',
    'minimumVersion': '2.0.0',
    'storeUrl': null,
    'releaseNotes': null,
  },
];
