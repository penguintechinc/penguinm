import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';

void main() {
  test('sanitize masks token keys at any depth', () {
    final input = <String, Object?>{
      'accessToken': 'abcdef1234',
      'nested': <String, Object?>{
        'password': 'hunter2xyz',
        'list': <Object?>[
          <String, Object?>{'apiKey': 'secretvalue9999'},
          'plain',
        ],
      },
    };

    final result = LogSanitizer.sanitize(input);

    expect(result['accessToken'], '****1234');
    final nested = result['nested']! as Map<String, Object?>;
    expect(nested['password'], '****2xyz');
    final list = nested['list']! as List<Object?>;
    final firstItem = list[0]! as Map<String, Object?>;
    expect(firstItem['apiKey'], '****9999');
    expect(list[1], 'plain');
  });

  test('sanitize leaves non-sensitive keys', () {
    final input = <String, Object?>{
      'userId': 'u-123',
      'count': 5,
      'nested': <String, Object?>{'name': 'gazer'},
    };

    final result = LogSanitizer.sanitize(input);

    expect(result, <String, Object?>{
      'userId': 'u-123',
      'count': 5,
      'nested': <String, Object?>{'name': 'gazer'},
    });
  });

  test('maskValue keeps last four', () {
    expect(LogSanitizer.maskValue('abcdef1234'), '****1234');
    expect(LogSanitizer.maskValue('1234'), '****');
    expect(LogSanitizer.maskValue('abc'), '****');
    expect(LogSanitizer.maskValue(''), '****');
  });

  test('sanitize recurses into a loosely-typed nested map', () {
    final input = <String, Object?>{
      'meta': <Object?, Object?>{'password': 'hunter2xyz', 1: 'kept'},
    };

    final result = LogSanitizer.sanitize(input);

    final meta = result['meta']! as Map<String, Object?>;
    expect(meta['password'], '****2xyz');
    expect(meta['1'], 'kept');
  });

  test(
    'sanitize matches sensitive keys case-insensitively and handles null',
    () {
      final input = <String, Object?>{
        'AUTHORIZATION': null,
        'Session-Cookie': 'sid-9876',
      };

      final result = LogSanitizer.sanitize(input);

      expect(result['AUTHORIZATION'], isNull);
      expect(result['Session-Cookie'], '****9876');
    },
  );

  test('sanitize recurses into Set and Iterable types', () {
    final input = <String, Object?>{
      'tokens': <Object?>{'abcdef1234', 'secret9876'}.cast<Object?>(),
      'items': <Object?>[5, 'data'],
    };

    final result = LogSanitizer.sanitize(input);

    expect(result['tokens'], isNotNull);
    expect(result['items'], isA<List<Object?>>());
  });

  test('scrubText masks Bearer tokens', () {
    final text = 'Bearer secrettoken1234567890';
    final result = LogSanitizer.scrubText(text);
    expect(result, contains('Bearer ****'));
    expect(result, isNot(contains('secrettoken')));
  });

  test('scrubText leaves harmless messages unchanged', () {
    final text = 'Connection established to example.com on port 8080';
    final result = LogSanitizer.scrubText(text);
    expect(result, text);
  });

  test('scrubText masks key=value patterns', () {
    final text = 'auth_token=abc123def456';
    final result = LogSanitizer.scrubText(text);
    expect(result, contains('auth_token=****'));
    expect(result, isNot(contains('abc123')));
  });

  test('scrubText masks JSON "key":"value" patterns', () {
    final text = '{"api_key":"secret9876"}';
    final result = LogSanitizer.scrubText(text);
    expect(result, contains('"api_key":"****'));
    expect(result, isNot(contains('secret9876')));
  });

  test('scrubText masks a raw JWT-shaped string outside key/value context', () {
    const text = 'JWT observed in request: aaaaaaaa.bbbbbbbb.cccccccc end';

    final result = LogSanitizer.scrubText(text);

    expect(result, 'JWT observed in request: ****aaaa.****bbbb.****cccc end');
    expect(result, isNot(contains('aaaaaaaa')));
    expect(result, isNot(contains('bbbbbbbb')));
    expect(result, isNot(contains('cccccccc')));
  });

  test('sanitize recurses into a Set nested under a non-sensitive key', () {
    final input = <String, Object?>{
      'entries': <Object?>{
        <String, Object?>{'password': 'hunter2xyz'},
        'plainValue',
      },
    };

    final result = LogSanitizer.sanitize(input);

    expect(result['entries'], isA<Set<Object?>>());
    final resultSet = result['entries']! as Set<Object?>;
    expect(resultSet, hasLength(2));
    expect(
      resultSet,
      contains(equals(<String, Object?>{'password': '****2xyz'})),
    );
    expect(resultSet, contains('plainValue'));
  });
}
