import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'manifest.dart';

/// Entry point — all wiring lives in the shell; see manifest.dart.
Future<void> main() => runPenguinApp(buildManifest());
