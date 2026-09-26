import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('ElderThemeData.dark', () {
    test('exposes the Elder dark palette', () {
      const dark = ElderThemeData.dark;

      expect(dark.pageBackground, ElderColors.slate950);
      expect(dark.cardBackground, ElderColors.slate800);
      expect(dark.cardBorder, ElderColors.slate700);
      expect(dark.titleText, ElderColors.amber400);
      expect(dark.subtitleText, ElderColors.slate400);
      expect(dark.labelText, ElderColors.amber300);
      expect(dark.bodyText, ElderColors.slate300);
      expect(dark.inputBackground, ElderColors.slate900);
      expect(dark.inputBorder, ElderColors.slate600);
      expect(dark.inputFocusBorder, ElderColors.amber500);
      expect(dark.inputText, ElderColors.white);
      expect(dark.primaryButton, ElderColors.amber500);
      expect(dark.primaryButtonHover, ElderColors.amber600);
      expect(dark.primaryButtonText, ElderColors.slate900);
      expect(dark.secondaryButton, ElderColors.slate700);
      expect(dark.secondaryButtonBorder, ElderColors.slate600);
      expect(dark.errorText, ElderColors.red400);
      expect(dark.successText, ElderColors.green400);
      expect(dark.linkText, ElderColors.amber400);
      expect(dark.linkHoverText, ElderColors.amber300);
      expect(dark.divider, ElderColors.slate700);
    });
  });

  group('ElderThemeData.copyWith', () {
    test('returns an equivalent instance when called with no arguments', () {
      const dark = ElderThemeData.dark;
      final copy = dark.copyWith();

      expect(copy.pageBackground, dark.pageBackground);
      expect(copy.cardBackground, dark.cardBackground);
      expect(copy.cardBorder, dark.cardBorder);
      expect(copy.titleText, dark.titleText);
      expect(copy.subtitleText, dark.subtitleText);
      expect(copy.labelText, dark.labelText);
      expect(copy.bodyText, dark.bodyText);
      expect(copy.inputBackground, dark.inputBackground);
      expect(copy.inputBorder, dark.inputBorder);
      expect(copy.inputFocusBorder, dark.inputFocusBorder);
      expect(copy.inputText, dark.inputText);
      expect(copy.primaryButton, dark.primaryButton);
      expect(copy.primaryButtonHover, dark.primaryButtonHover);
      expect(copy.primaryButtonText, dark.primaryButtonText);
      expect(copy.secondaryButton, dark.secondaryButton);
      expect(copy.secondaryButtonBorder, dark.secondaryButtonBorder);
      expect(copy.errorText, dark.errorText);
      expect(copy.successText, dark.successText);
      expect(copy.linkText, dark.linkText);
      expect(copy.linkHoverText, dark.linkHoverText);
      expect(copy.divider, dark.divider);
    });

    test('overrides every field when all arguments are given', () {
      const dark = ElderThemeData.dark;
      final copy = dark.copyWith(
        pageBackground: Colors.pink,
        cardBackground: Colors.pink,
        cardBorder: Colors.pink,
        titleText: Colors.pink,
        subtitleText: Colors.pink,
        labelText: Colors.pink,
        bodyText: Colors.pink,
        inputBackground: Colors.pink,
        inputBorder: Colors.pink,
        inputFocusBorder: Colors.pink,
        inputText: Colors.pink,
        primaryButton: Colors.pink,
        primaryButtonHover: Colors.pink,
        primaryButtonText: Colors.pink,
        secondaryButton: Colors.pink,
        secondaryButtonBorder: Colors.pink,
        errorText: Colors.pink,
        successText: Colors.pink,
        linkText: Colors.pink,
        linkHoverText: Colors.pink,
        divider: Colors.pink,
      );

      expect(copy.pageBackground, Colors.pink);
      expect(copy.cardBackground, Colors.pink);
      expect(copy.cardBorder, Colors.pink);
      expect(copy.titleText, Colors.pink);
      expect(copy.subtitleText, Colors.pink);
      expect(copy.labelText, Colors.pink);
      expect(copy.bodyText, Colors.pink);
      expect(copy.inputBackground, Colors.pink);
      expect(copy.inputBorder, Colors.pink);
      expect(copy.inputFocusBorder, Colors.pink);
      expect(copy.inputText, Colors.pink);
      expect(copy.primaryButton, Colors.pink);
      expect(copy.primaryButtonHover, Colors.pink);
      expect(copy.primaryButtonText, Colors.pink);
      expect(copy.secondaryButton, Colors.pink);
      expect(copy.secondaryButtonBorder, Colors.pink);
      expect(copy.errorText, Colors.pink);
      expect(copy.successText, Colors.pink);
      expect(copy.linkText, Colors.pink);
      expect(copy.linkHoverText, Colors.pink);
      expect(copy.divider, Colors.pink);

      // Original instance is untouched (immutability).
      expect(dark.pageBackground, ElderColors.slate950);
    });

    test('overrides a single field and keeps the rest', () {
      const dark = ElderThemeData.dark;
      final copy = dark.copyWith(titleText: Colors.teal);

      expect(copy.titleText, Colors.teal);
      expect(copy.subtitleText, dark.subtitleText);
      expect(copy.pageBackground, dark.pageBackground);
    });
  });

  group('ElderThemeData.lerp', () {
    test('at t=0 matches the starting colors', () {
      const dark = ElderThemeData.dark;
      final other = dark.copyWith(pageBackground: Colors.black);

      final result = dark.lerp(other, 0);

      expect(result.pageBackground.toARGB32(), dark.pageBackground.toARGB32());
      expect(result.cardBackground.toARGB32(), dark.cardBackground.toARGB32());
      expect(result.divider.toARGB32(), dark.divider.toARGB32());
    });

    test('at t=1 matches the destination colors', () {
      const dark = ElderThemeData.dark;
      final other = dark.copyWith(
        pageBackground: Colors.black,
        cardBackground: Colors.white,
        cardBorder: Colors.red,
        titleText: Colors.green,
        subtitleText: Colors.blue,
        labelText: Colors.yellow,
        bodyText: Colors.orange,
        inputBackground: Colors.purple,
        inputBorder: Colors.cyan,
        inputFocusBorder: Colors.teal,
        inputText: Colors.black,
        primaryButton: Colors.white,
        primaryButtonHover: Colors.red,
        primaryButtonText: Colors.green,
        secondaryButton: Colors.blue,
        secondaryButtonBorder: Colors.yellow,
        errorText: Colors.orange,
        successText: Colors.purple,
        linkText: Colors.cyan,
        linkHoverText: Colors.teal,
        divider: Colors.black,
      );

      final result = dark.lerp(other, 1);

      expect(result.pageBackground.toARGB32(), other.pageBackground.toARGB32());
      expect(result.cardBackground.toARGB32(), other.cardBackground.toARGB32());
      expect(result.cardBorder.toARGB32(), other.cardBorder.toARGB32());
      expect(result.titleText.toARGB32(), other.titleText.toARGB32());
      expect(result.subtitleText.toARGB32(), other.subtitleText.toARGB32());
      expect(result.labelText.toARGB32(), other.labelText.toARGB32());
      expect(result.bodyText.toARGB32(), other.bodyText.toARGB32());
      expect(
        result.inputBackground.toARGB32(),
        other.inputBackground.toARGB32(),
      );
      expect(result.inputBorder.toARGB32(), other.inputBorder.toARGB32());
      expect(
        result.inputFocusBorder.toARGB32(),
        other.inputFocusBorder.toARGB32(),
      );
      expect(result.inputText.toARGB32(), other.inputText.toARGB32());
      expect(result.primaryButton.toARGB32(), other.primaryButton.toARGB32());
      expect(
        result.primaryButtonHover.toARGB32(),
        other.primaryButtonHover.toARGB32(),
      );
      expect(
        result.primaryButtonText.toARGB32(),
        other.primaryButtonText.toARGB32(),
      );
      expect(
        result.secondaryButton.toARGB32(),
        other.secondaryButton.toARGB32(),
      );
      expect(
        result.secondaryButtonBorder.toARGB32(),
        other.secondaryButtonBorder.toARGB32(),
      );
      expect(result.errorText.toARGB32(), other.errorText.toARGB32());
      expect(result.successText.toARGB32(), other.successText.toARGB32());
      expect(result.linkText.toARGB32(), other.linkText.toARGB32());
      expect(result.linkHoverText.toARGB32(), other.linkHoverText.toARGB32());
      expect(result.divider.toARGB32(), other.divider.toARGB32());
    });

    test('at t=0.5 blends between the two colors', () {
      const dark = ElderThemeData.dark;
      final other = dark.copyWith(pageBackground: Colors.white);

      final result = dark.lerp(other, 0.5);
      final expected = Color.lerp(
        dark.pageBackground,
        other.pageBackground,
        0.5,
      )!;

      expect(result.pageBackground.toARGB32(), expected.toARGB32());
    });

    test('returns this when other is not an ElderThemeData', () {
      const dark = ElderThemeData.dark;
      final result = dark.lerp(null, 0.5);

      expect(identical(result, dark), isTrue);
    });
  });

  group('ElderThemeData as a ThemeExtension', () {
    test('registers on ThemeData and is retrievable', () {
      final theme = ThemeData.dark().copyWith(
        extensions: const [ElderThemeData.dark],
      );

      final extension = theme.extension<ElderThemeData>();

      expect(extension, isNotNull);
      expect(extension!.pageBackground, ElderColors.slate950);
    });

    testWidgets('is retrievable through Theme.of in the widget tree', (
      tester,
    ) async {
      ElderThemeData? found;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [ElderThemeData.dark],
          ),
          home: Builder(
            builder: (context) {
              found = Theme.of(context).extension<ElderThemeData>();
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(found, isNotNull);
      expect(found!.titleText, ElderColors.amber400);
    });
  });
}
