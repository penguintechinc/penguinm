import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('elderLoginTheme', () {
    test('matches LoginColorConfig.elder', () {
      expect(
        elderLoginTheme.pageBackground,
        LoginColorConfig.elder.pageBackground,
      );
      expect(elderLoginTheme.titleText, LoginColorConfig.elder.titleText);
      expect(elderLoginTheme.errorText, LoginColorConfig.elder.errorText);
    });

    test('matches the Elder slate/amber defaults', () {
      expect(elderLoginTheme.pageBackground, ElderColors.slate950);
      expect(elderLoginTheme.cardBackground, ElderColors.slate800);
      expect(elderLoginTheme.titleText, ElderColors.amber400);
      expect(elderLoginTheme.primaryButton, ElderColors.amber500);
      expect(elderLoginTheme.errorText, ElderColors.red400);
    });
  });

  group('mergeWithElderTheme', () {
    test('returns the Elder defaults when called with no overrides', () {
      final merged = mergeWithElderTheme();

      expect(merged.pageBackground, LoginColorConfig.elder.pageBackground);
      expect(merged.titleText, LoginColorConfig.elder.titleText);
      expect(merged.primaryButton, LoginColorConfig.elder.primaryButton);
    });

    test('returns the given overrides unchanged', () {
      const overrides = LoginColorConfig(
        titleText: Colors.deepPurple,
        primaryButton: Colors.deepPurple,
      );

      final merged = mergeWithElderTheme(overrides: overrides);

      expect(merged.titleText, Colors.deepPurple);
      expect(merged.primaryButton, Colors.deepPurple);
      // Fields not overridden still fall back to LoginColorConfig's own
      // defaults (not necessarily the Elder theme's, since this helper
      // returns the overrides object as-is).
      expect(merged.cardBackground, ElderColors.slate800);
    });

    test('is the identity function over its overrides argument', () {
      const overrides = LoginColorConfig(titleText: Colors.teal);
      final merged = mergeWithElderTheme(overrides: overrides);

      expect(identical(merged, overrides), isTrue);
    });
  });
}
