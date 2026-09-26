/// Four deterministic community-member fixtures, as plain JSON maps
/// referencing [communityFixtures] and [userFixtures] ids by convention
/// only (no foreign-key type coupling to either).
const List<Map<String, Object?>> memberFixtures = <Map<String, Object?>>[
  <String, Object?>{
    'id': 'member-0001',
    'communityId': 'community-0001',
    'userId': 'user-0001',
    'role': 'owner',
    'joinedAt': '2026-01-01T00:00:00.000Z',
  },
  <String, Object?>{
    'id': 'member-0002',
    'communityId': 'community-0001',
    'userId': 'user-0002',
    'role': 'moderator',
    'joinedAt': '2026-01-02T00:00:00.000Z',
  },
  <String, Object?>{
    'id': 'member-0003',
    'communityId': 'community-0002',
    'userId': 'user-0003',
    'role': 'member',
    'joinedAt': '2026-01-06T00:00:00.000Z',
  },
  <String, Object?>{
    'id': 'member-0004',
    'communityId': 'community-0003',
    'userId': 'user-0004',
    'role': 'member',
    'joinedAt': '2026-01-11T00:00:00.000Z',
  },
];
