import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_telemetry/src/queue.dart';

void main() {
  test('add below capacity keeps every item, no drops', () {
    final queue = BoundedQueue<int>(maxSize: 3)
      ..add(1)
      ..add(2);

    expect(queue.length, 2);
    expect(queue.droppedCount, 0);
    expect(queue.isEmpty, isFalse);
  });

  test('add beyond capacity evicts oldest and counts drops', () {
    final queue = BoundedQueue<int>(maxSize: 2)
      ..add(1)
      ..add(2)
      ..add(3)
      ..add(4);

    expect(queue.droppedCount, 2);
    expect(queue.drain(), <int>[3, 4]);
  });

  test('drain empties the queue and returns items oldest first', () {
    final queue = BoundedQueue<int>(maxSize: 5)
      ..add(1)
      ..add(2)
      ..add(3);

    final drained = queue.drain();

    expect(drained, <int>[1, 2, 3]);
    expect(queue.isEmpty, isTrue);
    expect(queue.length, 0);
  });

  test('an empty queue drains to an empty list', () {
    final queue = BoundedQueue<int>(maxSize: 5);

    expect(queue.drain(), isEmpty);
  });
}
