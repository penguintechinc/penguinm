import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_testing/penguin_testing.dart';

void main() {
  group('FakeFlagSource', () {
    test('defaults to an empty successful flag map', () async {
      final source = FakeFlagSource();
      final result = await source.fetch(distinctId: 'installation-1');
      expect(result.isOk, isTrue);
      expect(result.valueOrNull, isEmpty);
    });

    test('records distinctId and properties for every call', () async {
      final source = FakeFlagSource();
      await source.fetch(
        distinctId: 'installation-1',
        properties: const {'plan': 'free'},
      );
      await source.fetch(distinctId: 'installation-2');

      expect(source.distinctIds, ['installation-1', 'installation-2']);
      expect(source.properties, [
        const {'plan': 'free'},
        const <String, String>{},
      ]);
    });

    test(
      'setResult changes the value returned by subsequent fetches',
      () async {
        final source = FakeFlagSource();
        source.setResult(
          const Result.ok(<String, Object?>{'waddlebot.chat': true}),
        );
        final result = await source.fetch(distinctId: 'installation-1');
        expect(result.valueOrNull, {'waddlebot.chat': true});
      },
    );

    test('can be scripted to fail', () async {
      final source = FakeFlagSource();
      source.setResult(const Result.err(NetworkFailure('unreachable')));
      final result = await source.fetch(distinctId: 'installation-1');
      expect(result.isOk, isFalse);
    });
  });
}
