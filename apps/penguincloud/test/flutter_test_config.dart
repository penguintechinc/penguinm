import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Load system fonts for golden tests to avoid Ahem boxes.
///
/// This loads Roboto and MaterialIcons from the Flutter SDK's cache,
/// enabling proper font rendering in goldens on Linux. Goldens are
/// Linux-rendered. Mirrors `shells/penguin_app_shell/test/flutter_test_config.dart`.
Future<void> testExecutable(Future<void> Function() testMain) async {
  // Resolve Flutter SDK root by walking up from flutter_tester binary.
  String? flutterSdkRoot;
  final executable = Platform.resolvedExecutable;
  var current = File(executable).parent;
  while (current.path != current.parent.path) {
    final fontsDir = Directory(
      '${current.path}/bin/cache/artifacts/material_fonts',
    );
    if (await fontsDir.exists()) {
      flutterSdkRoot = current.path;
      break;
    }
    current = current.parent;
  }

  if (flutterSdkRoot == null) {
    throw Exception(
      'Flutter SDK not found. Walked up from $executable without finding '
      'bin/cache/artifacts/material_fonts. Goldens require system fonts.',
    );
  }

  // Load Roboto for text rendering.
  final robotoPath =
      '$flutterSdkRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf';
  final robotoFile = File(robotoPath);
  if (!await robotoFile.exists()) {
    throw Exception(
      'Roboto font not found at $robotoPath. Golden tests require system fonts.',
    );
  }

  final robotoBytes = await robotoFile.readAsBytes();
  final robotoBd = ByteData.view(robotoBytes.buffer);
  final robotoLoader = FontLoader('Roboto');
  robotoLoader.addFont(Future<ByteData>.value(robotoBd));
  await robotoLoader.load();

  // Load MaterialIcons for icon rendering.
  final iconsPath =
      '$flutterSdkRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final iconsFile = File(iconsPath);
  if (await iconsFile.exists()) {
    final iconsBytes = await iconsFile.readAsBytes();
    final iconsBd = ByteData.view(iconsBytes.buffer);
    final iconsLoader = FontLoader('MaterialIcons');
    iconsLoader.addFont(Future<ByteData>.value(iconsBd));
    await iconsLoader.load();
  }

  return testMain();
}
