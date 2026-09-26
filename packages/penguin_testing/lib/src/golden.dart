import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

/// Default logical surface size for [penguinGolden] captures — a phone
/// portrait viewport, matching the smallest of the three sizes golden tests
/// cover per spec §4.9 (phone/tablet/expanded).
const Size penguinGoldenPhoneSize = Size(390, 844);

/// Captures a golden image of whatever [finder] locates within [tester]'s
/// already-pumped widget tree, resizing the test surface to [size] first
/// (restored automatically via [WidgetTester.addTearDown]) and settling
/// animations before comparing against `goldens/<name>.png`. Callers pump
/// their own widget tree first (this package deliberately has no
/// dependency on the shell, so it never builds one itself).
Future<void> penguinGolden(
  WidgetTester tester,
  Finder finder,
  String name, {
  Size size = penguinGoldenPhoneSize,
}) async {
  final view = tester.view;
  final previousSize = view.physicalSize;
  final previousRatio = view.devicePixelRatio;
  view.physicalSize = size * previousRatio;
  addTearDown(() {
    view.physicalSize = previousSize;
    view.devicePixelRatio = previousRatio;
  });
  await tester.pumpAndSettle();
  await expectLater(finder, matchesGoldenFile('goldens/$name.png'));
}
