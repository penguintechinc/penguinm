/// Field types for [FormBuilder].
enum FieldType {
  /// Single-line text input.
  text,

  /// Email input with email validation keyboard.
  email,

  /// Password input with obscured text.
  password,

  /// Numeric input with number keyboard.
  number,

  /// Multi-line text input.
  textarea,

  /// Dropdown select from options.
  select,

  /// Checkbox for boolean input.
  checkbox,

  /// Radio button group (one per option).
  radio,

  /// Date picker with calendar UI.
  date,

  /// Time picker with clock UI.
  time,

  /// DateTime input combining date and time.
  datetimeLocal,

  /// Telephone number input.
  tel,

  /// URL input with URL validation keyboard.
  url,
}

/// Option for select/radio fields.
class SelectOption {
  /// Creates a select option.
  const SelectOption({required this.value, required this.label});

  /// The option's internal value (submitted with the form).
  final String value;

  /// The option's display label shown to the user.
  final String label;
}

/// Configuration for a single field in [FormBuilder].
class FieldConfig {
  /// Creates a field configuration.
  const FieldConfig({
    required this.name,
    required this.label,
    required this.type,
    this.placeholder,
    this.required = false,
    this.disabled = false,
    this.autoFocus = false,
    this.min,
    this.max,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.step,
    this.rows,
    this.options,
    this.helperText,
    this.validate,
    this.onChange,
  });

  /// Unique identifier for this field (form value key).
  final String name;

  /// Label displayed above the field.
  final String label;

  /// The type of input widget to render.
  final FieldType type;

  /// Placeholder text when field is empty.
  final String? placeholder;

  /// Whether the field must have a non-empty value.
  final bool required;

  /// Whether the field is read-only.
  final bool disabled;

  /// Whether to focus this field on mount.
  final bool autoFocus;

  /// Minimum numeric value (for number fields).
  final num? min;

  /// Maximum numeric value (for number fields).
  final num? max;

  /// Minimum string length (for text fields).
  final int? minLength;

  /// Maximum string length (for text fields).
  final int? maxLength;

  /// Regex pattern for validation.
  final String? pattern;

  /// Increment step for number inputs.
  final num? step;

  /// Row count for textarea fields.
  final int? rows;

  /// Options for select/radio fields.
  final List<SelectOption>? options;

  /// Helper text below the field.
  final String? helperText;

  /// Validation function returning error message or null if valid.
  final String? Function(dynamic value)? validate;

  /// Callback invoked when field value changes.
  final void Function(dynamic value)? onChange;
}

/// Configuration for the entire [FormBuilder].
class FormConfig {
  /// Creates a form configuration.
  const FormConfig({
    required this.fields,
    this.title,
    this.submitLabel = 'Submit',
    this.cancelLabel = 'Cancel',
    this.validateOnChange = false,
    this.validateOnBlur = true,
  });

  /// List of fields in the form.
  final List<FieldConfig> fields;

  /// Title displayed above the form (modal mode only).
  final String? title;

  /// Label for the submit button.
  final String submitLabel;

  /// Label for the cancel button.
  final String cancelLabel;

  /// Whether to validate fields as they change.
  final bool validateOnChange;

  /// Whether to validate fields when they lose focus.
  final bool validateOnBlur;
}
