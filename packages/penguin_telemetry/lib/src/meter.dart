import 'package:penguin_core/penguin_core.dart';

import 'instruments.dart';
import 'otlp_json.dart';

/// Creates and caches named metric instruments (counters, histograms,
/// gauges). One [Meter] backs a whole `Telemetry` instance so repeated
/// `meter.counter('x')` calls return the same accumulating instrument.
class Meter {
  /// Creates a meter that stamps every instrument's timestamps from [clock].
  Meter({this._clock = const SystemClock()});

  final Clock _clock;
  final Map<String, Counter> _counters = <String, Counter>{};
  final Map<String, Histogram> _histograms = <String, Histogram>{};
  final Map<String, _GaugeInstrument> _gauges = <String, _GaugeInstrument>{};

  /// Returns the named counter, creating it (with [unit]/[description]) on
  /// first use.
  Counter counter(String name, {String unit = '1', String description = ''}) {
    return _counters.putIfAbsent(
      name,
      () => Counter(
        name: name,
        unit: unit,
        description: description,
        clock: _clock,
      ),
    );
  }

  /// Returns the named histogram, creating it on first use; [boundaries]
  /// only takes effect the first time [name] is requested.
  Histogram histogram(
    String name, {
    String unit = 'ms',
    String description = '',
    List<double> boundaries = defaultMsBoundaries,
  }) {
    return _histograms.putIfAbsent(
      name,
      () => Histogram(
        name: name,
        unit: unit,
        description: description,
        boundaries: boundaries,
        clock: _clock,
      ),
    );
  }

  /// Registers [observe] to be called at export time for the named
  /// observable gauge, creating it on first use. Calling this again with
  /// the same [name] replaces the previously registered [observe] callback
  /// (the last caller wins) rather than keeping the first one; [unit] is
  /// fixed on first registration and ignored on later calls.
  ObservableGauge gauge(
    String name,
    double Function() observe, {
    String unit = '1',
  }) {
    final instrument = _gauges.putIfAbsent(
      name,
      () => _GaugeInstrument(name: name, unit: unit, clock: _clock),
    );
    instrument.observe = observe;
    return ObservableGauge(name, unit);
  }

  /// Records a push-style gauge reading with [attributes] — used by
  /// `TelemetryMetricsSink.gauge`, which (unlike [gauge]) supplies a value
  /// per call rather than a pull callback, so readings are tracked per
  /// attribute combination instead of via a single `observe` callback.
  void recordGaugeValue(
    String name,
    double value,
    Map<String, Object?> attributes, {
    String unit = '1',
  }) {
    final instrument = _gauges.putIfAbsent(
      name,
      () => _GaugeInstrument(name: name, unit: unit, clock: _clock),
    );
    instrument.setPushedValue(attributes, value);
  }

  /// Snapshots every registered instrument for export.
  List<MetricData> collect() {
    return <MetricData>[
      for (final counter in _counters.values) counter.snapshot(),
      for (final histogram in _histograms.values) histogram.snapshot(),
      for (final gauge in _gauges.values) gauge.snapshot(),
    ];
  }
}

class _GaugeInstrument {
  _GaugeInstrument({
    required this.name,
    required this.unit,
    required this._clock,
  });

  final String name;
  final String unit;
  final Clock _clock;
  double Function()? observe;
  final Map<String, _PushedGaugeValue> _pushed = <String, _PushedGaugeValue>{};

  void setPushedValue(Map<String, Object?> attributes, double value) {
    final sanitized = LogSanitizer.sanitize(attributes);
    final key = sanitized.entries.map((e) => '${e.key}=${e.value}').join('&');
    _pushed[key] = _PushedGaugeValue(sanitized, value);
  }

  MetricData snapshot() {
    final now = _clock.now();
    final observeFn = observe;
    final points = <MetricDataPoint>[
      for (final pushed in _pushed.values)
        MetricDataPoint(
          startTime: now,
          time: now,
          value: pushed.value,
          attributes: pushed.attributes,
        ),
      if (observeFn != null)
        MetricDataPoint(startTime: now, time: now, value: observeFn()),
    ];
    return MetricData.gauge(name: name, unit: unit, dataPoints: points);
  }
}

class _PushedGaugeValue {
  _PushedGaugeValue(this.attributes, this.value);
  final Map<String, Object?> attributes;
  final double value;
}
