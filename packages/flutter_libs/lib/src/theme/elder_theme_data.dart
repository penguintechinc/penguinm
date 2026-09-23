import 'package:flutter/material.dart';
import 'elder_colors.dart';

/// Theme extension providing Elder dark theme colors to the widget tree.
///
/// Usage:
/// ```dart
/// Theme(
///   data: ThemeData.dark().copyWith(
///     extensions: [ElderThemeData.dark],
///   ),
///   child: MyApp(),
/// )
/// ```
///
/// Access in widgets:
/// ```dart
/// final elder = Theme.of(context).extension<ElderThemeData>()!;
/// ```
@immutable
class ElderThemeData extends ThemeExtension<ElderThemeData> {
  /// Creates an [ElderThemeData] with the specified colors.
  const ElderThemeData({
    required this.pageBackground,
    required this.cardBackground,
    required this.cardBorder,
    required this.titleText,
    required this.subtitleText,
    required this.labelText,
    required this.bodyText,
    required this.inputBackground,
    required this.inputBorder,
    required this.inputFocusBorder,
    required this.inputText,
    required this.primaryButton,
    required this.primaryButtonHover,
    required this.primaryButtonText,
    required this.secondaryButton,
    required this.secondaryButtonBorder,
    required this.errorText,
    required this.successText,
    required this.linkText,
    required this.linkHoverText,
    required this.divider,
  });

  /// Background color for page content areas.
  final Color pageBackground;

  /// Background color for cards and containers.
  final Color cardBackground;

  /// Border color for cards.
  final Color cardBorder;

  /// Color for primary headings and titles.
  final Color titleText;

  /// Color for secondary headings and subtitles.
  final Color subtitleText;

  /// Color for form labels and field names.
  final Color labelText;

  /// Color for body text content.
  final Color bodyText;

  /// Background color for input fields.
  final Color inputBackground;

  /// Border color for input fields in default state.
  final Color inputBorder;

  /// Border color for input fields when focused.
  final Color inputFocusBorder;

  /// Color for text inside input fields.
  final Color inputText;

  /// Background color for primary action buttons.
  final Color primaryButton;

  /// Background color for primary buttons in hover state.
  final Color primaryButtonHover;

  /// Text color for primary buttons.
  final Color primaryButtonText;

  /// Background color for secondary action buttons.
  final Color secondaryButton;

  /// Border color for secondary buttons.
  final Color secondaryButtonBorder;

  /// Color for error messages and alerts.
  final Color errorText;

  /// Color for success messages and confirmations.
  final Color successText;

  /// Color for hyperlink text.
  final Color linkText;

  /// Color for hyperlink text in hover state.
  final Color linkHoverText;

  /// Color for dividers and separators.
  final Color divider;

  /// The default Elder dark theme.
  static const ElderThemeData dark = ElderThemeData(
    pageBackground: ElderColors.slate950,
    cardBackground: ElderColors.slate800,
    cardBorder: ElderColors.slate700,
    titleText: ElderColors.amber400,
    subtitleText: ElderColors.slate400,
    labelText: ElderColors.amber300,
    bodyText: ElderColors.slate300,
    inputBackground: ElderColors.slate900,
    inputBorder: ElderColors.slate600,
    inputFocusBorder: ElderColors.amber500,
    inputText: ElderColors.white,
    primaryButton: ElderColors.amber500,
    primaryButtonHover: ElderColors.amber600,
    primaryButtonText: ElderColors.slate900,
    secondaryButton: ElderColors.slate700,
    secondaryButtonBorder: ElderColors.slate600,
    errorText: ElderColors.red400,
    successText: ElderColors.green400,
    linkText: ElderColors.amber400,
    linkHoverText: ElderColors.amber300,
    divider: ElderColors.slate700,
  );

  /// Returns a copy of this theme with the specified colors replaced.
  @override
  ElderThemeData copyWith({
    Color? pageBackground,
    Color? cardBackground,
    Color? cardBorder,
    Color? titleText,
    Color? subtitleText,
    Color? labelText,
    Color? bodyText,
    Color? inputBackground,
    Color? inputBorder,
    Color? inputFocusBorder,
    Color? inputText,
    Color? primaryButton,
    Color? primaryButtonHover,
    Color? primaryButtonText,
    Color? secondaryButton,
    Color? secondaryButtonBorder,
    Color? errorText,
    Color? successText,
    Color? linkText,
    Color? linkHoverText,
    Color? divider,
  }) {
    return ElderThemeData(
      pageBackground: pageBackground ?? this.pageBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      titleText: titleText ?? this.titleText,
      subtitleText: subtitleText ?? this.subtitleText,
      labelText: labelText ?? this.labelText,
      bodyText: bodyText ?? this.bodyText,
      inputBackground: inputBackground ?? this.inputBackground,
      inputBorder: inputBorder ?? this.inputBorder,
      inputFocusBorder: inputFocusBorder ?? this.inputFocusBorder,
      inputText: inputText ?? this.inputText,
      primaryButton: primaryButton ?? this.primaryButton,
      primaryButtonHover: primaryButtonHover ?? this.primaryButtonHover,
      primaryButtonText: primaryButtonText ?? this.primaryButtonText,
      secondaryButton: secondaryButton ?? this.secondaryButton,
      secondaryButtonBorder:
          secondaryButtonBorder ?? this.secondaryButtonBorder,
      errorText: errorText ?? this.errorText,
      successText: successText ?? this.successText,
      linkText: linkText ?? this.linkText,
      linkHoverText: linkHoverText ?? this.linkHoverText,
      divider: divider ?? this.divider,
    );
  }

  /// Linearly interpolates between this theme and [other] at progress [t].
  @override
  ElderThemeData lerp(ElderThemeData? other, double t) {
    if (other is! ElderThemeData) return this;
    return ElderThemeData(
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      titleText: Color.lerp(titleText, other.titleText, t)!,
      subtitleText: Color.lerp(subtitleText, other.subtitleText, t)!,
      labelText: Color.lerp(labelText, other.labelText, t)!,
      bodyText: Color.lerp(bodyText, other.bodyText, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      inputFocusBorder: Color.lerp(
        inputFocusBorder,
        other.inputFocusBorder,
        t,
      )!,
      inputText: Color.lerp(inputText, other.inputText, t)!,
      primaryButton: Color.lerp(primaryButton, other.primaryButton, t)!,
      primaryButtonHover: Color.lerp(
        primaryButtonHover,
        other.primaryButtonHover,
        t,
      )!,
      primaryButtonText: Color.lerp(
        primaryButtonText,
        other.primaryButtonText,
        t,
      )!,
      secondaryButton: Color.lerp(secondaryButton, other.secondaryButton, t)!,
      secondaryButtonBorder: Color.lerp(
        secondaryButtonBorder,
        other.secondaryButtonBorder,
        t,
      )!,
      errorText: Color.lerp(errorText, other.errorText, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      linkText: Color.lerp(linkText, other.linkText, t)!,
      linkHoverText: Color.lerp(linkHoverText, other.linkHoverText, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
    );
  }
}
