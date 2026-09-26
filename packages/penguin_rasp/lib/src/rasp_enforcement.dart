import 'package:flutter/foundation.dart';

/// Whether RASP should ENFORCE (terminate the app on a blocking threat).
/// Defaults to release-only; override at build with
/// `--dart-define=RASP_ENFORCE=true|false` so debug/emulator builds run
/// unblocked (detection + telemetry still fire).
const bool raspEnforcementEnabled = bool.hasEnvironment('RASP_ENFORCE')
    ? bool.fromEnvironment('RASP_ENFORCE')
    : kReleaseMode;
