import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_testing/penguin_testing.dart';

void _expectFourWithDeterministicIds(
  List<Map<String, Object?>> fixtures,
  String prefix,
) {
  expect(fixtures, hasLength(4));
  for (var i = 0; i < fixtures.length; i++) {
    final expectedId = '$prefix-${(i + 1).toString().padLeft(4, '0')}';
    expect(fixtures[i]['id'], expectedId);
  }
  final ids = fixtures.map((f) => f['id']).toSet();
  expect(ids, hasLength(4), reason: 'fixture ids must be unique');
}

void main() {
  group('fixtures', () {
    test('userFixtures has 4 deterministic entries', () {
      _expectFourWithDeterministicIds(userFixtures, 'user');
    });

    test('springboardItemFixtures has 4 deterministic entries', () {
      _expectFourWithDeterministicIds(springboardItemFixtures, 'springboard');
    });

    test('clientVersionFixtures has 4 deterministic entries', () {
      _expectFourWithDeterministicIds(clientVersionFixtures, 'clientversion');
    });

    test('communityFixtures has 4 deterministic entries', () {
      _expectFourWithDeterministicIds(communityFixtures, 'community');
    });

    test('memberFixtures has 4 deterministic entries', () {
      _expectFourWithDeterministicIds(memberFixtures, 'member');
    });

    test('chatMessageFixtures has 4 deterministic entries', () {
      _expectFourWithDeterministicIds(chatMessageFixtures, 'chatmessage');
    });

    test('no fixture email uses anything but example.com', () {
      for (final user in userFixtures) {
        expect(user['email'], endsWith('@example.com'));
      }
    });

    test(
      'member and chat-message fixtures reference existing user/community ids',
      () {
        final userIds = userFixtures.map((u) => u['id']).toSet();
        final communityIds = communityFixtures.map((c) => c['id']).toSet();

        for (final member in memberFixtures) {
          expect(userIds, contains(member['userId']));
          expect(communityIds, contains(member['communityId']));
        }
        for (final message in chatMessageFixtures) {
          expect(userIds, contains(message['authorId']));
          expect(communityIds, contains(message['communityId']));
        }
      },
    );
  });
}
