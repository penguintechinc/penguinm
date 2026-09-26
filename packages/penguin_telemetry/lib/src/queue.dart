/// A fixed-capacity FIFO queue that silently drops the oldest item when a
/// new one arrives at capacity, so a stalled or slow exporter can never grow
/// memory unbounded on a mobile device. Backs the logs and spans buffers
/// inside `Telemetry`.
class BoundedQueue<T> {
  /// Creates a queue that holds at most [maxSize] items.
  BoundedQueue({required this.maxSize})
    : assert(maxSize > 0, 'maxSize must be positive');

  /// The maximum number of items retained at once.
  final int maxSize;

  final List<T> _items = <T>[];
  int _droppedCount = 0;

  /// Number of items ever evicted because the queue was full when [add] was
  /// called.
  int get droppedCount => _droppedCount;

  /// Current number of items waiting to be drained.
  int get length => _items.length;

  /// True when no items are waiting.
  bool get isEmpty => _items.isEmpty;

  /// Appends [item], evicting the oldest item first (and incrementing
  /// [droppedCount]) when already at [maxSize].
  void add(T item) {
    if (_items.length >= maxSize) {
      _items.removeAt(0);
      _droppedCount += 1;
    }
    _items.add(item);
  }

  /// Removes and returns every queued item, oldest first, leaving the queue
  /// empty; used to take a batch for export.
  List<T> drain() {
    final drained = List<T>.of(_items);
    _items.clear();
    return drained;
  }
}
