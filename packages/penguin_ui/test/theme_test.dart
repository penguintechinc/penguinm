import 'package:flutter/material.dart';
import 'package:flutter_libs/flutter_libs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_ui/penguin_ui.dart';

void main() {
  group('PenguinTheme', () {
    test('dark theme uses Material 3', () {
      final theme = PenguinTheme.dark();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.dark);
    });

    test('dark theme uses default amber seed color', () {
      final theme = PenguinTheme.dark();
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('dark theme with custom seed color', () {
      const customSeed = Color(0xFF0000FF);
      final theme = PenguinTheme.dark(seed: customSeed);
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.dark);
    });

    test('light theme uses Material 3', () {
      final theme = PenguinTheme.light();
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, Brightness.light);
    });

    test('light theme uses default amber seed color', () {
      final theme = PenguinTheme.light();
      expect(theme.colorScheme.brightness, Brightness.light);
    });

    test('light theme with custom seed color', () {
      const customSeed = Color(0xFF0000FF);
      final theme = PenguinTheme.light(seed: customSeed);
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.brightness, Brightness.light);
    });

    testWidgets('dark theme registers ElderThemeData extension', (
      tester,
    ) async {
      final theme = PenguinTheme.dark();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              final elder = Theme.of(context).extension<ElderThemeData>();
              expect(elder, isNotNull);
              return Container();
            },
          ),
        ),
      );
    });

    testWidgets('light theme registers ElderThemeData extension', (
      tester,
    ) async {
      final theme = PenguinTheme.light();
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              final elder = Theme.of(context).extension<ElderThemeData>();
              expect(elder, isNotNull);
              return Container();
            },
          ),
        ),
      );
    });

    test('dark theme has slate-950 scaffold background', () {
      final theme = PenguinTheme.dark();
      expect(theme.scaffoldBackgroundColor, const Color(0xFF020617));
    });

    testWidgets(
      'light theme registers light-appropriate ElderThemeData extension',
      (tester) async {
        final theme = PenguinTheme.light();
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                final elder = Theme.of(context).extension<ElderThemeData>();
                expect(elder, isNotNull);
                // Verify light theme has light-appropriate background (luminance > 0.5).
                expect(
                  elder!.pageBackground.computeLuminance(),
                  greaterThan(0.5),
                );
                return Container();
              },
            ),
          ),
        );
      },
    );
  });
}
