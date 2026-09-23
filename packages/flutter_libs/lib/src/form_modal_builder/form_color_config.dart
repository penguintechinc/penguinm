import 'package:flutter/material.dart';
import '../theme/elder_colors.dart';

/// Color configuration for [FormModalBuilder].
///
/// All colors default to the Elder dark theme palette.
class FormColorConfig {
  /// Creates a color configuration.
  const FormColorConfig({
    this.modalBackground = ElderColors.slate800,
    this.headerBackground = ElderColors.slate800,
    this.footerBackground = ElderColors.slate900,
    this.overlayBackground = const Color(0x80000000),
    this.titleText = ElderColors.amber400,
    this.labelText = ElderColors.amber300,
    this.descriptionText = ElderColors.slate400,
    this.errorText = ElderColors.red400,
    this.buttonText = ElderColors.slate900,
    this.fieldBackground = ElderColors.white,
    this.fieldBorder = ElderColors.slate600,
    this.fieldText = ElderColors.slate900,
    this.fieldPlaceholder = ElderColors.slate400,
    this.focusRing = ElderColors.amber500,
    this.focusBorder = ElderColors.amber500,
    this.primaryButton = ElderColors.amber500,
    this.primaryButtonHover = ElderColors.amber600,
    this.secondaryButton = ElderColors.slate700,
    this.secondaryButtonHover = ElderColors.slate600,
    this.secondaryButtonBorder = ElderColors.slate600,
    this.secondaryButtonText = ElderColors.slate300,
    this.activeTab = ElderColors.amber400,
    this.activeTabBorder = ElderColors.amber500,
    this.inactiveTab = ElderColors.slate400,
    this.inactiveTabHover = ElderColors.slate300,
    this.tabBorder = ElderColors.slate700,
    this.errorTabText = ElderColors.red400,
    this.errorTabBorder = ElderColors.red500,
    this.checkboxActive = ElderColors.amber500,
    this.radioActive = ElderColors.amber500,
    this.disabledBackground = ElderColors.slate700,
    this.disabledText = ElderColors.slate500,
  });

  /// Background color of the modal dialog.
  final Color modalBackground;

  /// Background color of the modal header.
  final Color headerBackground;

  /// Background color of the modal footer.
  final Color footerBackground;

  /// Overlay color behind the modal.
  final Color overlayBackground;

  /// Color for the modal title text.
  final Color titleText;

  /// Color for field labels.
  final Color labelText;

  /// Color for field descriptions.
  final Color descriptionText;

  /// Color for error messages.
  final Color errorText;

  /// Color for button text.
  final Color buttonText;

  /// Background color for form fields.
  final Color fieldBackground;

  /// Border color for form fields.
  final Color fieldBorder;

  /// Text color inside form fields.
  final Color fieldText;

  /// Color for field placeholder text.
  final Color fieldPlaceholder;

  /// Focus ring color for fields.
  final Color focusRing;

  /// Focus border color for fields.
  final Color focusBorder;

  /// Background color for primary buttons.
  final Color primaryButton;

  /// Hover color for primary buttons.
  final Color primaryButtonHover;

  /// Background color for secondary buttons.
  final Color secondaryButton;

  /// Hover color for secondary buttons.
  final Color secondaryButtonHover;

  /// Border color for secondary buttons.
  final Color secondaryButtonBorder;

  /// Text color for secondary buttons.
  final Color secondaryButtonText;

  /// Color for active tab text.
  final Color activeTab;

  /// Border color for active tabs.
  final Color activeTabBorder;

  /// Color for inactive tab text.
  final Color inactiveTab;

  /// Hover color for inactive tabs.
  final Color inactiveTabHover;

  /// Border color for tabs.
  final Color tabBorder;

  /// Text color for error tabs.
  final Color errorTabText;

  /// Border color for error tabs.
  final Color errorTabBorder;

  /// Color for active checkboxes.
  final Color checkboxActive;

  /// Color for active radio buttons.
  final Color radioActive;

  /// Background color for disabled elements.
  final Color disabledBackground;

  /// Text color for disabled elements.
  final Color disabledText;

  /// Default Elder dark theme configuration.
  static const FormColorConfig elder = FormColorConfig();
}
