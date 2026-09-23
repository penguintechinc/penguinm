import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_config.dart';
import 'app_config_controller.dart';
import 'clock.dart';
import 'console_logger.dart';
import 'logger.dart';
import 'sinks.dart';

/// Live [AppConfig] state, mutable at runtime via [AppConfigController].
final appConfigProvider = NotifierProvider<AppConfigController, AppConfig>(
  AppConfigController.new,
);

/// System clock; override with a fake in tests that need deterministic
/// time.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Structured logger; overridden with a telemetry-backed logger once
/// telemetry starts (see `penguin_telemetry`).
final loggerProvider = Provider<PenguinLogger>((ref) => ConsoleLogger());

/// Metrics emission sink; a no-op until `penguin_telemetry` overrides it.
final metricsSinkProvider = Provider<MetricsSink>(
  (ref) => const NoopMetricsSink(),
);

/// Trace span sink; a no-op until `penguin_telemetry` overrides it.
final traceSinkProvider = Provider<TraceSink>((ref) => const NoopTraceSink());
