import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/penguin_flags.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

void main() {
  group('FeatureGate', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Future<FeatureFlags> buildFlags({
      required WidgetTester tester,
      required FakeFlagSource flagSource,
      required FakeLicenseSource licenseSource,
    }) async {
      final flags = FeatureFlags(
        config: FlagsConfig(
          productKey: 'penguinm',
          posthogHost: 'https://posthog.example.com',
          posthogProjectKey: 'test-key',
          licenseServerUrl: Uri.parse('https://license.example.com'),
        ),
        flags: flagSource,
        license: licenseSource,
        cache: FlagCache(),
        log: ConsoleLogger(sink: (_) {}),
      );
      await flags.initialize(distinctId: 'test');
      // initialize()'s refresh runs via unawaited(); flush the pending
      // work so the fake source's fetch has resolved before pumping the
      // widget tree. `testWidgets` runs inside a FakeAsync zone, where a
      // raw `Future.delayed` (even Duration.zero) schedules a real Timer
      // that never fires without an explicit pump — awaiting it directly
      // hangs the test forever. `tester.pump(Duration.zero)` elapses the
      // fake clock and flushes microtasks, which is the safe equivalent.
      await tester.pump(Duration.zero);
      return flags;
    }

    testWidgets('shows child when flag enabled', (tester) async {
      final flagSource = FakeFlagSource()
        ..setFlagValue('penguinm.feature', true);
      final flags = await buildFlags(
        tester: tester,
        flagSource: flagSource,
        licenseSource: FakeLicenseSource(),
      );
      addTearDown(flags.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [featureFlagsProvider.overrideWithValue(flags)],
          child: const MaterialApp(
            home: Scaffold(
              body: FeatureGate(
                flag: 'penguinm.feature',
                fallback: Text('Feature hidden'),
                child: Text('Feature visible'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Feature visible'), findsOneWidget);
      expect(find.text('Feature hidden'), findsNothing);
    });

    testWidgets('shows fallback when flag disabled', (tester) async {
      final flagSource = FakeFlagSource()
        ..setFlagValue('penguinm.feature', false);
      final flags = await buildFlags(
        tester: tester,
        flagSource: flagSource,
        licenseSource: FakeLicenseSource(),
      );
      addTearDown(flags.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [featureFlagsProvider.overrideWithValue(flags)],
          child: const MaterialApp(
            home: Scaffold(
              body: FeatureGate(
                flag: 'penguinm.feature',
                fallback: Text('Feature hidden'),
                child: Text('Feature visible'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Feature hidden'), findsOneWidget);
      expect(find.text('Feature visible'), findsNothing);
    });

    testWidgets('shows child when tier requirement satisfied', (tester) async {
      final flagSource = FakeFlagSource()
        ..setFlagValue('penguinm.feature', true);
      final licenseSource = FakeLicenseSource()
        ..setTier(LicenseTier.professional);
      final flags = await buildFlags(
        tester: tester,
        flagSource: flagSource,
        licenseSource: licenseSource,
      );
      addTearDown(flags.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [featureFlagsProvider.overrideWithValue(flags)],
          child: const MaterialApp(
            home: Scaffold(
              body: FeatureGate(
                flag: 'penguinm.feature',
                tier: LicenseTier.professional,
                fallback: Text('Premium hidden'),
                child: Text('Premium visible'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Premium visible'), findsOneWidget);
    });

    testWidgets('shows fallback when tier requirement not satisfied', (
      tester,
    ) async {
      final flagSource = FakeFlagSource()
        ..setFlagValue('penguinm.feature', true);
      final flags = await buildFlags(
        tester: tester,
        flagSource: flagSource,
        licenseSource: FakeLicenseSource(),
      );
      addTearDown(flags.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [featureFlagsProvider.overrideWithValue(flags)],
          child: const MaterialApp(
            home: Scaffold(
              body: FeatureGate(
                flag: 'penguinm.feature',
                tier: LicenseTier.enterprise,
                fallback: Text('Premium hidden'),
                child: Text('Premium visible'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Premium hidden'), findsOneWidget);
      expect(find.text('Premium visible'), findsNothing);
    });

    testWidgets('reacts to flag changes via refresh', (tester) async {
      final flagSource = FakeFlagSource()
        ..setFlagValue('penguinm.feature', true);
      final flags = await buildFlags(
        tester: tester,
        flagSource: flagSource,
        licenseSource: FakeLicenseSource(),
      );
      addTearDown(flags.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [featureFlagsProvider.overrideWithValue(flags)],
          child: const MaterialApp(
            home: Scaffold(
              body: FeatureGate(
                flag: 'penguinm.feature',
                fallback: Text('Feature hidden'),
                child: Text('Feature visible'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Feature visible'), findsOneWidget);

      flagSource.setFlagValue('penguinm.feature', false);
      await flags.refresh();
      // `changes` is a broadcast stream: `add()` delivers to listeners on a
      // microtask, so `flagChangesProvider` hasn't observed the event yet.
      // One pump flushes that microtask and schedules the rebuild frame;
      // a second pump renders it. Deliberately explicit pumps rather than
      // `pumpAndSettle()` — no animation/timer here needs an open-ended
      // settle loop, and an explicit pump can't silently wait out a
      // perpetual one if a future change introduces it.
      await tester.pump();
      await tester.pump();

      expect(find.text('Feature hidden'), findsOneWidget);
      expect(find.text('Feature visible'), findsNothing);
    });

    testWidgets('shows empty SizedBox when fallback omitted', (tester) async {
      final flagSource = FakeFlagSource()
        ..setFlagValue('penguinm.feature', false);
      final flags = await buildFlags(
        tester: tester,
        flagSource: flagSource,
        licenseSource: FakeLicenseSource(),
      );
      addTearDown(flags.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [featureFlagsProvider.overrideWithValue(flags)],
          child: const MaterialApp(
            home: Scaffold(
              body: FeatureGate(
                flag: 'penguinm.feature',
                child: Text('Feature visible'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Feature visible'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}
