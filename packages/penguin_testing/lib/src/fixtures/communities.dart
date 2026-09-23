/// Four deterministic community fixtures (Waddles-style chat/community
/// management), as plain JSON maps so this package stays independent of
/// any product's domain model.
const List<Map<String, Object?>> communityFixtures = <Map<String, Object?>>[
  <String, Object?>{
    'id': 'community-0001',
    'name': 'Icebreakers',
    'description': 'General chatter for new members.',
    'memberCount': 42,
    'createdAt': '2026-01-01T00:00:00.000Z',
  },
  <String, Object?>{
    'id': 'community-0002',
    'name': 'Flipper Feedback',
    'description': 'Product feedback and feature requests.',
    'memberCount': 17,
    'createdAt': '2026-01-05T00:00:00.000Z',
  },
  <String, Object?>{
    'id': 'community-0003',
    'name': 'Overnight Watch',
    'description': 'Coordination for the night-shift moderator team.',
    'memberCount': 6,
    'createdAt': '2026-01-10T00:00:00.000Z',
  },
  <String, Object?>{
    'id': 'community-0004',
    'name': 'Archive',
    'description': 'Read-only historical community, kept for reference.',
    'memberCount': 3,
    'createdAt': '2025-06-01T00:00:00.000Z',
  },
];
