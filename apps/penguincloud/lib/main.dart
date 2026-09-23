import 'package:flutter/widgets.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';

import 'manifest.dart';

/// Entry point: hands the PenguinCloud manifest to the shell's
/// bootstrap-and-run flow. No logic or widgets belong here — see
/// `manifest.dart` for app wiring.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await runPenguinApp(buildManifest());
}
