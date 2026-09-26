import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';

void main() {
  test('SystemClock.now returns the real current time', () {
    const clock = SystemClock();
    final before = DateTime.now();
    final now = clock.now();
    final after = DateTime.now();

    expect(now.isAfter(before.subtract(const Duration(seconds: 2))), isTrue);
    expect(now.isBefore(after.add(const Duration(seconds: 2))), isTrue);
  });

  test('clockProvider defaults to SystemClock', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(clockProvider), isA<SystemClock>());
  });
}
