import 'dart:io';

import 'package:flutter/services.dart';

/// Terminates the app in response to a blocking RASP threat. Only ever
/// invoked by `RaspGuard` when it is both a block-type threat and
/// `raspEnforcementEnabled` (debug/emulator builds never enforce, so this
/// never runs there). Pops the platform navigator first so the OS records
/// a clean app exit, then hard-exits the process — there is no recovering
/// from a confirmed integrity threat. Injected into `RaspGuard.onBlock` by
/// `Bootstrap.run` as the default `ShellServices.onRaspBlock` (swappable
/// for a spy in tests) rather than called directly, so it must never be
/// exercised by a test.
void raspTerminate() {
  SystemNavigator.pop();
  exit(0);
}
