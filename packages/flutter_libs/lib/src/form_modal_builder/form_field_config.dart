/// Field types supported by [FormModalBuilder].
enum FormFieldType {
  /// Single-line text input.
  text,

  /// Email input with email validation.
  email,

  /// Password input with obscured text.
  password,

  /// Password input with generate button.
  passwordGenerate,

  /// Numeric input.
  number,

  /// Telephone number input.
  tel,

  /// URL input with URL validation.
  url,

  /// Multi-line text area.
  textarea,

  /// Multi-line text input.
  multiline,

  /// Dropdown select from options.
  select,

  /// Single checkbox.
  checkbox,

  /// Multiple checkboxes.
  checkboxMulti,

  /// Radio button group.
  radio,

  /// Date picker.
  date,

  /// Time picker.
  time,

  /// DateTime picker.
  datetimeLocal,

  /// File upload (single).
  file,

  /// File upload (multiple).
  fileMultiple,
}

/// Option for select, radio, and checkbox_multi fields.
class FormFieldOption {
  /// Creates a field option.
  const FormFieldOption({required this.value, required this.label});

  /// The option's value.
  final dynamic value;

  /// The option's display label.
  final String label;
}

/// Configuration for a single form field in [FormModalBuilder].
class FormFieldConfig {
  /// Creates a field configuration.
  const FormFieldConfig({
    required this.name,
    required this.type,
    required this.label,
    this.description,
    this.helpText,
    this.defaultValue,
    this.placeholder,
    this.required = false,
    this.disabled = false,
    this.hidden = false,
    this.options,
    this.min,
    this.max,
    this.pattern,
    this.accept,
    this.rows,
    this.triggerField,
    this.showWhen,
    this.onPasswordGenerated,
    this.maxFileSize,
    this.maxFiles,
    this.tab,
  });

  /// Unique identifier for this field.
  final String name;

  /// The type of input widget to render.
  final FormFieldType type;

  /// Label displayed above the field.
  final String label;

  /// Longer description text below the label.
  final String? description;

  /// Helper text below the field.
  final String? helpText;

  /// Default value for the field.
  final dynamic defaultValue;

  /// Placeholder text when field is empty.
  final String? placeholder;

  /// Whether the field must have a non-empty value.
  final bool required;

  /// Whether the field is read-only.
  final bool disabled;

  /// Whether the field should be hidden from the form.
  final bool hidden;

  /// Options for select/radio/checkbox_multi fields.
  final List<FormFieldOption>? options;

  /// Minimum numeric value.
  final num? min;

  /// Maximum numeric value.
  final num? max;

  /// Regex pattern for validation.
  final String? pattern;

  /// Accepted file types for file upload.
  final String? accept;

  /// Row count for textarea fields.
  final int? rows;

  /// Name of field that triggers conditional visibility.
  final String? triggerField;

  /// Function determining field visibility based on form values.
  final bool Function(Map<String, dynamic> values)? showWhen;

  /// Callback when password is generated.
  final void Function(String password)? onPasswordGenerated;

  /// Maximum file size in bytes.
  final int? maxFileSize;

  /// Maximum number of files for multi-file upload.
  final int? maxFiles;

  /// Tab name for organizing fields in tabs.
  final String? tab;
}
