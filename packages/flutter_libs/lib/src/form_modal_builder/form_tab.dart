/// A tab grouping for form fields in [FormModalBuilder].
class FormTab {
  /// Creates a tab configuration.
  const FormTab({
    required this.id,
    required this.label,
    this.icon,
    this.description,
  });

  /// Unique identifier for this tab.
  final String id;

  /// Tab label displayed in the tab bar.
  final String label;

  /// Optional icon widget for the tab.
  final dynamic icon;

  /// Optional description text below the tab label.
  final String? description;
}
