import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_testing/penguin_testing.dart';

void main() {
  group('FakeClock', () {
    test('defaults to a fixed deterministic instant', () {
      final clock = FakeClock();
      expect(clock.now(), DateTime.utc(2026));
    });

    test('starts at the given initial time', () {
      final initial = DateTime.utc(2030, 6, 15);
      final clock = FakeClock(initial);
      expect(clock.now(), initial);
    });

    test('set replaces the current time', () {
      final clock = FakeClock();
      final next = DateTime.utc(2027, 3, 1);
      clock.set(next);
      expect(clock.now(), next);
    });

    test('advance moves the current time forward', () {
      final clock = FakeClock(DateTime.utc(2026));
      clock.advance(const Duration(hours: 2));
      expect(clock.now(), DateTime.utc(2026, 1, 1, 2));
    });

    test('advance with a negative duration moves time backward', () {
      final clock = FakeClock(DateTime.utc(2026, 1, 2));
      clock.advance(const Duration(days: -1));
      expect(clock.now(), DateTime.utc(2026));
    });
  });
}
