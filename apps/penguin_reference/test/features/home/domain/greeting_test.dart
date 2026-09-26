import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_reference/features/home/domain/greeting.dart';

void main() {
  group('Greeting', () {
    test('equality and hashCode are value-based', () {
      const a = Greeting(text: 'hi');
      const b = Greeting(text: 'hi');
      const c = Greeting(text: 'bye');

      expect(a, equals(a));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(Object())));
    });

    test('toString includes the greeting text', () {
      const greeting = Greeting(text: 'hi');
      expect(greeting.toString(), contains('hi'));
    });
  });
}
