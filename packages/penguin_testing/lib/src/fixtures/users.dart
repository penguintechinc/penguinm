/// Four deterministic user fixtures shaped like a typical product `users`
/// API payload — plain JSON maps (not a typed model) so this package never
/// needs a dependency on any product-specific user model. Ids are
/// deterministic (`user-0001`..`user-0004`) and email addresses use the
/// RFC 2606 reserved `example.com` domain; no real personal data.
const List<Map<String, Object?>> userFixtures = <Map<String, Object?>>[
  <String, Object?>{
    'id': 'user-0001',
    'email': 'penny.waddle@example.com',
    'displayName': 'Penny Waddle',
    'tenant': 'tenant-0001',
    'roles': <String>['admin'],
    'createdAt': '2026-01-01T00:00:00.000Z',
  },
  <String, Object?>{
    'id': 'user-0002',
    'email': 'gus.flipper@example.com',
    'displayName': 'Gus Flipper',
    'tenant': 'tenant-0001',
    'roles': <String>['maintainer'],
    'createdAt': '2026-01-02T00:00:00.000Z',
  },
  <String, Object?>{
    'id': 'user-0003',
    'email': 'chilly.bergman@example.com',
    'displayName': 'Chilly Bergman',
    'tenant': 'tenant-0001',
    'roles': <String>['viewer'],
    'createdAt': '2026-01-03T00:00:00.000Z',
  },
  <String, Object?>{
    'id': 'user-0004',
    'email': 'skipper.molt@example.com',
    'displayName': 'Skipper Molt',
    'tenant': 'tenant-0002',
    'roles': <String>['viewer'],
    'createdAt': '2026-01-04T00:00:00.000Z',
  },
];
