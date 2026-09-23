import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'telemetry.dart';

/// Riverpod provider for the running [Telemetry] instance; the app shell
/// overrides this once `Telemetry.start` resolves during startup — reading
/// it before that override is a programming error.
final Provider<Telemetry> telemetryProvider = Provider<Telemetry>(
  (ref) => throw UnimplementedError(
    'telemetryProvider must be overridden after Telemetry.start()',
  ),
);
