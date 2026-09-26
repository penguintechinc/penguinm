import 'package:flutter/material.dart';
import '../theme/elder_colors.dart';

/// Color configuration for [LoginPageBuilder].
///
/// All colors default to the Elder dark theme palette.
class LoginColorConfig {
  /// Creates a [LoginColorConfig] with customizable theme colors.
  const LoginColorConfig({
    this.pageBackground = ElderColors.slate950,
    this.cardBackground = ElderColors.slate800,
    this.cardBorder = ElderColors.slate700,
    this.titleText = ElderColors.amber400,
    this.subtitleText = ElderColors.slate400,
    this.labelText = ElderColors.amber300,
    this.inputBackground = ElderColors.slate900,
    this.inputBorder = ElderColors.slate600,
    this.inputFocusBorder = ElderColors.amber500,
    this.inputText = ElderColors.white,
    this.inputPlaceholder = ElderColors.slate500,
    this.primaryButton = ElderColors.amber500,
    this.primaryButtonHover = ElderColors.amber600,
    this.primaryButtonText = ElderColors.slate900,
    this.socialButtonBackground = ElderColors.slate700,
    this.socialButtonBorder = ElderColors.slate600,
    this.socialButtonText = ElderColors.white,
    this.socialButtonHover = ElderColors.slate600,
    this.errorText = ElderColors.red400,
    this.errorBackground = const Color(0x1AF87171),
    this.successText = ElderColors.green400,
    this.linkText = ElderColors.amber400,
    this.linkHoverText = ElderColors.amber300,
    this.dividerColor = ElderColors.slate700,
    this.checkboxActive = ElderColors.amber500,
    this.footerText = ElderColors.slate500,
    this.mfaBackground = ElderColors.slate800,
    this.mfaInputBackground = ElderColors.slate900,
    this.mfaInputBorder = ElderColors.slate600,
    this.captchaBackground = ElderColors.slate900,
  });

  /// Color for the page background.
  final Color pageBackground;

  /// Color for card backgrounds.
  final Color cardBackground;

  /// Color for card borders.
  final Color cardBorder;

  /// Color for title text.
  final Color titleText;

  /// Color for subtitle text.
  final Color subtitleText;

  /// Color for input labels.
  final Color labelText;

  /// Color for input field backgrounds.
  final Color inputBackground;

  /// Color for input field borders.
  final Color inputBorder;

  /// Color for focused input field borders.
  final Color inputFocusBorder;

  /// Color for input text.
  final Color inputText;

  /// Color for input placeholder text.
  final Color inputPlaceholder;

  /// Color for primary button backgrounds.
  final Color primaryButton;

  /// Color for primary button hover state.
  final Color primaryButtonHover;

  /// Color for primary button text.
  final Color primaryButtonText;

  /// Color for social button backgrounds.
  final Color socialButtonBackground;

  /// Color for social button borders.
  final Color socialButtonBorder;

  /// Color for social button text.
  final Color socialButtonText;

  /// Color for social button hover state.
  final Color socialButtonHover;

  /// Color for error message text.
  final Color errorText;

  /// Color for error message backgrounds.
  final Color errorBackground;

  /// Color for success message text.
  final Color successText;

  /// Color for link text.
  final Color linkText;

  /// Color for link text on hover.
  final Color linkHoverText;

  /// Color for divider lines.
  final Color dividerColor;

  /// Color for active checkbox state.
  final Color checkboxActive;

  /// Color for footer text.
  final Color footerText;

  /// Color for MFA section backgrounds.
  final Color mfaBackground;

  /// Color for MFA input field backgrounds.
  final Color mfaInputBackground;

  /// Color for MFA input field borders.
  final Color mfaInputBorder;

  /// Color for CAPTCHA backgrounds.
  final Color captchaBackground;

  /// Default Elder dark theme configuration.
  static const LoginColorConfig elder = LoginColorConfig();
}
