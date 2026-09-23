import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('ConsoleVersion', () {
    testWidgets('renders nothing visible with full parameters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConsoleVersion(
            appName: 'Elder',
            version: 'v1.2.3.1700000000',
            environment: 'beta',
            metadata: const {'source': 'test'},
          ),
        ),
      );

      expect(find.byType(ConsoleVersion), findsOneWidget);
      final box = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(ConsoleVersion),
          matching: find.byType(SizedBox),
        ),
      );
      expect(box.width, 0.0);
      expect(box.height, 0.0);
      expect(box.child, isNull);
    });

    testWidgets('renders nothing visible with only required parameters', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConsoleVersion(appName: 'Elder', version: '1.0.0'),
        ),
      );

      expect(find.byType(ConsoleVersion), findsOneWidget);
      expect(find.byType(SizedBox), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('accepts a custom styleConfig', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConsoleVersion(
            appName: 'Elder',
            version: '2.0.0',
            styleConfig: const ConsoleStyleConfig(fontFamily: 'Courier'),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('logs once on mount without throwing for a bare version', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConsoleVersion(appName: 'BareApp', version: 'not-a-semver'),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
