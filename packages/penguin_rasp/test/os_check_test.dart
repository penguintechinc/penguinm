import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:penguin_rasp/penguin_rasp.dart';

class _MockDeviceInfoPlugin extends Mock implements DeviceInfoPlugin {}

class _MockAndroidDeviceInfo extends Mock implements AndroidDeviceInfo {}

class _MockIosDeviceInfo extends Mock implements IosDeviceInfo {}

void main() {
  // `defaultTargetPlatform` defaults to `TargetPlatform.android` under
  // `flutter test` (the framework forces this for determinism across host
  // OSes); every group below sets the override it actually needs and
  // resets it in `tearDown` so no test leaks its platform into the next.
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('detectAndroidSdk', () {
    test('off Android returns null without touching the plugin', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final plugin = _MockDeviceInfoPlugin();
      expect(await detectAndroidSdk(plugin: plugin), isNull);
      verifyNever(() => plugin.androidInfo);
    });

    test('on Android returns AndroidDeviceInfo.version.sdkInt', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final plugin = _MockDeviceInfoPlugin();
      final info = _MockAndroidDeviceInfo();
      when(() => info.version).thenReturn(
        AndroidBuildVersion.setMockInitialValues(
          codename: 'REL',
          incremental: '1',
          previewSdkInt: 0,
          release: '14',
          sdkInt: 34,
        ),
      );
      when(() => plugin.androidInfo).thenAnswer((_) async => info);

      expect(await detectAndroidSdk(plugin: plugin), 34);
    });

    test('on Android, plugin failure is swallowed and returns null', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final plugin = _MockDeviceInfoPlugin();
      when(() => plugin.androidInfo).thenThrow(StateError('no platform'));

      expect(await detectAndroidSdk(plugin: plugin), isNull);
    });
  });

  group('detectIosVersion', () {
    test('off iOS returns null without touching the plugin', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final plugin = _MockDeviceInfoPlugin();
      expect(await detectIosVersion(plugin: plugin), isNull);
      verifyNever(() => plugin.iosInfo);
    });

    test('on iOS returns IosDeviceInfo.systemVersion', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final plugin = _MockDeviceInfoPlugin();
      final info = _MockIosDeviceInfo();
      when(() => info.systemVersion).thenReturn('17.4');
      when(() => plugin.iosInfo).thenAnswer((_) async => info);

      expect(await detectIosVersion(plugin: plugin), '17.4');
    });

    test('on iOS, plugin failure is swallowed and returns null', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final plugin = _MockDeviceInfoPlugin();
      when(() => plugin.iosInfo).thenThrow(StateError('no platform'));

      expect(await detectIosVersion(plugin: plugin), isNull);
    });
  });

  group('isIosVersionBelow', () {
    test('below: 14.0 vs 15.0 is true', () {
      expect(isIosVersionBelow('14.0', '15.0'), isTrue);
    });

    test('equal: 15.0 vs 15.0 is false', () {
      expect(isIosVersionBelow('15.0', '15.0'), isFalse);
    });

    test('above: 16.1 vs 15.0 is false', () {
      expect(isIosVersionBelow('16.1', '15.0'), isFalse);
    });

    test('fewer segments than minimum: 14 vs 14.2 is true', () {
      expect(isIosVersionBelow('14', '14.2'), isTrue);
    });

    test('more segments than minimum: 14.2.1 vs 14.2 is false', () {
      expect(isIosVersionBelow('14.2.1', '14.2'), isFalse);
    });

    test('fewer segments, still above: 15 vs 14.9 is false', () {
      expect(isIosVersionBelow('15', '14.9'), isFalse);
    });

    test('malformed current (non-numeric segment) returns false', () {
      expect(isIosVersionBelow('14.x', '15.0'), isFalse);
    });

    test('malformed minimum (non-numeric segment) returns false', () {
      expect(isIosVersionBelow('14.0', '15.x'), isFalse);
    });

    test('empty current returns false', () {
      expect(isIosVersionBelow('', '15.0'), isFalse);
    });

    test('empty minimum returns false', () {
      expect(isIosVersionBelow('14.0', ''), isFalse);
    });

    test('both empty returns false', () {
      expect(isIosVersionBelow('', ''), isFalse);
    });
  });
}
