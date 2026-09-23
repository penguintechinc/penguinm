/// Four deterministic chat-message fixtures, as plain JSON maps
/// referencing [communityFixtures] and [userFixtures] ids by convention
/// only (no foreign-key type coupling to either).
const List<Map<String, Object?>> chatMessageFixtures = <Map<String, Object?>>[
  <String, Object?>{
    'id': 'chatmessage-0001',
    'communityId': 'community-0001',
    'authorId': 'user-0001',
    'body': 'Welcome to Icebreakers!',
    'sentAt': '2026-01-01T00:05:00.000Z',
  },
  <String, Object?>{
    'id': 'chatmessage-0002',
    'communityId': 'community-0001',
    'authorId': 'user-0002',
    'body': 'Glad to be here.',
    'sentAt': '2026-01-01T00:06:00.000Z',
  },
  <String, Object?>{
    'id': 'chatmessage-0003',
    'communityId': 'community-0002',
    'authorId': 'user-0003',
    'body': 'Filed a feature request for dark mode toggles.',
    'sentAt': '2026-01-06T09:00:00.000Z',
  },
  <String, Object?>{
    'id': 'chatmessage-0004',
    'communityId': 'community-0003',
    'authorId': 'user-0004',
    'body': 'Overnight watch handoff complete, all quiet.',
    'sentAt': '2026-01-11T23:59:00.000Z',
  },
];
