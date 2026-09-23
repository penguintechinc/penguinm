import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';

void main() {
  test('KnownApps.all has exactly fourteen entries', () {
    expect(KnownApps.all, hasLength(14));
  });

  test('KnownApps.all has unique ids', () {
    final ids = KnownApps.all.map((a) => a.id).toSet();
    expect(ids, hasLength(KnownApps.all.length));
  });

  test('KnownApps.all has unique applicationIds', () {
    final appIds = KnownApps.all.map((a) => a.applicationId).toSet();
    expect(appIds, hasLength(KnownApps.all.length));
  });

  test('every applicationId equals io.penguintech.<id>', () {
    for (final app in KnownApps.all) {
      expect(app.applicationId, 'io.penguintech.${app.id}');
    }
  });

  test('KnownApps.byId returns the matching app for a known id', () {
    final gazer = KnownApps.byId('gazer');
    expect(gazer, isNotNull);
    expect(gazer!.displayName, 'Gazer');
    expect(gazer.productKey, 'waddlebot');
  });

  test('KnownApps.byId returns null for an unknown id', () {
    expect(KnownApps.byId('does-not-exist'), isNull);
  });

  test('every app has a family', () {
    for (final app in KnownApps.all) {
      expect(app.family, isNotEmpty, reason: 'App ${app.id} has no family');
    }
  });

  test('app families match the spec', () {
    final familyMap = <String, String>{
      'gazer': 'Waddles',
      'waddles': 'Waddles',
      'ruffled': 'Waddles',
      'current': 'Current',
      'skauswatch': 'SkausWatch',
      'skauswatch_vault': 'SkausWatch',
      'elder': 'Elder',
      'elder_support': 'Elder',
      'nest_drive': 'Nest',
      'tobogganing': 'Tobogganing',
      'tobogganing_connect': 'Tobogganing',
      'tobogganing_squawk': 'Tobogganing',
      'penguincloud': 'PenguinCloud',
      'waddleai_chat': 'WaddleAI',
    };

    for (final app in KnownApps.all) {
      expect(
        app.family,
        familyMap[app.id],
        reason: 'App ${app.id} has incorrect family',
      );
    }
  });
}
