/// A single settings-validation failure: which [field] failed and an l10n
/// [messageKey] to render (never a hardcoded English string).
///
/// Produced by `TargetValidator.validate`; an empty issue list means the
/// settings are valid and Go Live may proceed.
///
/// Hand-written immutable value class (no code generation): const
/// constructor and value equality.
class ValidationIssue {
  /// Creates an immutable validation issue.
  const ValidationIssue({required this.field, required this.messageKey});

  /// Name of the settings field that failed validation.
  final String field;

  /// l10n message key describing the failure.
  final String messageKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ValidationIssue &&
          other.field == field &&
          other.messageKey == messageKey);

  @override
  int get hashCode => Object.hash(field, messageKey);

  @override
  String toString() =>
      'ValidationIssue(field: $field, messageKey: $messageKey)';
}
