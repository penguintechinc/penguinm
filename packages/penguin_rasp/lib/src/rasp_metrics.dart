/// Well-known OTel metric names emitted by RASP.
class RaspMetrics {
  const RaspMetrics._();

  /// Counter incremented once per detected threat.
  static const String threat = 'rasp.threat';

  /// Counter incremented on any RASP engine/detection failure.
  static const String failure = 'rasp.failure';
}
