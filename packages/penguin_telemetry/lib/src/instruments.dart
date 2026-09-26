import 'package:penguin_core/penguin_core.dart';

import 'otlp_json.dart';

String _attrKey(Map<String, Object?> attributes) {
  final keys = attributes.keys.toList()..sort();
  return keys.map((k) => '$k=${attributes[k]}').join('&');
}

/// A monotonic cumulative counter; each [add] call increases the running
/// total for its attribute combination since the instrument was created.
class Counter {
  /// Creates a counter instrument; normally obtained via `Meter.counter`
  /// rather than constructed directly.
  Counter({
    required this.name,
    required this.unit,
    required this.description,
    required Clock clock,
  }) : _clock = clock,
       _startTime = clock.now();

  /// Instrument name.
  final String name;

  /// Unit string.
  final String unit;

  /// Human-readable description.
  final String description;

  final Clock _clock;
  final DateTime _startTime;
  final Map<String, _NumberPoint> _points = <String, _NumberPoint>{};

  /// Adds [value] to the running total for [attributes]' series.
  void add(
    num value, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    final sanitized = LogSanitizer.sanitize(attributes);
    final key = _attrKey(sanitized);
    final point = _points.putIfAbsent(
      key,
      () => _NumberPoint(sanitized, _startTime),
    );
    point.value += value;
    point.time = _clock.now();
  }

  /// Snapshots every series as an OTLP sum metric.
  MetricData snapshot() {
    return MetricData.sum(
      name: name,
      unit: unit,
      description: description,
      dataPoints: _points.values
          .map(
            (p) => MetricDataPoint(
              startTime: p.startTime,
              time: p.time,
              value: p.value,
              attributes: p.attributes,
            ),
          )
          .toList(),
    );
  }
}

/// A cumulative histogram; each [record] call adds an observation to the
/// running count/sum/bucket totals for its attribute combination.
class Histogram {
  /// Creates a histogram instrument; normally obtained via
  /// `Meter.histogram` rather than constructed directly.
  Histogram({
    required this.name,
    required this.unit,
    required this.description,
    required this.boundaries,
    required Clock clock,
  }) : _clock = clock,
       _startTime = clock.now();

  /// Instrument name.
  final String name;

  /// Unit string.
  final String unit;

  /// Human-readable description.
  final String description;

  /// Upper bound (inclusive) of every bucket except the implicit last.
  final List<double> boundaries;

  final Clock _clock;
  final DateTime _startTime;
  final Map<String, _HistogramPoint> _points = <String, _HistogramPoint>{};

  /// Records a single observation of [value] for [attributes]' series.
  void record(
    num value, {
    Map<String, Object?> attributes = const <String, Object?>{},
  }) {
    final sanitized = LogSanitizer.sanitize(attributes);
    final key = _attrKey(sanitized);
    final point = _points.putIfAbsent(
      key,
      () => _HistogramPoint(sanitized, _startTime, boundaries.length + 1),
    );
    point.count += 1;
    point.sum += value;
    point.time = _clock.now();
    var bucket = boundaries.indexWhere((b) => value <= b);
    if (bucket == -1) bucket = boundaries.length;
    point.bucketCounts[bucket] += 1;
  }

  /// Snapshots every series as an OTLP histogram metric.
  MetricData snapshot() {
    return MetricData.histogram(
      name: name,
      unit: unit,
      description: description,
      dataPoints: _points.values
          .map(
            (p) => HistogramDataPoint(
              startTime: p.startTime,
              time: p.time,
              count: p.count,
              sum: p.sum,
              bucketCounts: List<int>.of(p.bucketCounts),
              explicitBounds: boundaries,
              attributes: p.attributes,
            ),
          )
          .toList(),
    );
  }
}

/// A pull-style gauge observed at export time; returned by `Meter.gauge` as
/// a handle to the instrument it registered.
class ObservableGauge {
  /// Creates a gauge handle; obtained via `Meter.gauge` rather than
  /// constructed directly.
  ObservableGauge(this.name, this.unit);

  /// Instrument name.
  final String name;

  /// Unit string.
  final String unit;
}

class _NumberPoint {
  _NumberPoint(this.attributes, this.startTime) : time = startTime;
  final Map<String, Object?> attributes;
  final DateTime startTime;
  DateTime time;
  double value = 0;
}

class _HistogramPoint {
  _HistogramPoint(this.attributes, this.startTime, int bucketCount)
    : time = startTime,
      bucketCounts = List<int>.filled(bucketCount, 0);
  final Map<String, Object?> attributes;
  final DateTime startTime;
  DateTime time;
  int count = 0;
  double sum = 0;
  final List<int> bucketCounts;
}
