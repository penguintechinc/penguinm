/// Four deterministic `GET /api/v1/auth/profile`-shaped fixtures for the
/// `profile` feature — reused across `ProfileRepository`/`ProfileScreen`
/// tests instead of each test hand-writing its own JSON, per the app
/// standard's "≥3 fixture items per feature" convention.
const List<Map<String, Object?>> profileJsonFixtures = [
  {
    'id': 'user-0001',
    'email': 'penny.waddle@example.com',
    'name': 'Penny Waddle',
    'roles': ['admin'],
  },
  {
    'id': 'user-0002',
    'email': 'gus.flipper@example.com',
    'name': 'Gus Flipper',
    'roles': ['maintainer'],
  },
  {
    'id': 'user-0003',
    'email': 'chilly.bergman@example.com',
    'name': 'Chilly Bergman',
    'roles': ['viewer'],
  },
  // No `name` — exercises the profile screen's "Unknown" display-name
  // fallback and the avatar initial sourced from `email` instead.
  {'id': 'user-0004', 'email': 'skipper.molt@example.com', 'roles': <String>[]},
];
