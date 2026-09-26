import 'package:flutter/material.dart';
import 'form_builder_types.dart';
import 'form_builder_field.dart';
import 'form_builder_modal.dart';
import 'form_builder_controller.dart';

/// A form widget supporting both inline and modal display modes.
///
/// Uses [FormBuilderController] for state management and validates fields
/// on change/blur/submit based on configuration.
class FormBuilder extends StatefulWidget {
  /// Creates a FormBuilder widget.
  const FormBuilder({
    super.key,
    required this.config,
    required this.onSubmit,
    this.onCancel,
    this.initialValues = const {},
    this.modal = false,
  });

  /// Form configuration including fields and validation settings.
  final FormConfig config;

  /// Callback invoked when form is submitted and validation passes.
  final Future<void> Function(Map<String, dynamic> values) onSubmit;

  /// Callback invoked when form is cancelled; defaults to [Navigator.pop].
  final VoidCallback? onCancel;

  /// Initial field values to populate the form.
  final Map<String, dynamic> initialValues;

  /// Whether to render as a modal dialog (true) or inline (false).
  final bool modal;

  @override
  State<FormBuilder> createState() => _FormBuilderState();
}

class _FormBuilderState extends State<FormBuilder> {
  late final FormBuilderController _controller;

  @override
  void initState() {
    super.initState();
    // Build a map of field validators from the config
    final validators = <String, String? Function(dynamic)>{};
    for (final field in widget.config.fields) {
      if (field.validate != null) {
        validators[field.name] = field.validate!;
      }
    }
    _controller = FormBuilderController(
      initialValues: widget.initialValues,
      validateOnChange: widget.config.validateOnChange,
      validateOnBlur: widget.config.validateOnBlur,
      onValidate: validators.isNotEmpty ? validators : null,
    );
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _handleSubmit() async {
    // Validate all fields before submitting
    if (!_controller.validateAll()) {
      return;
    }
    _controller.setSubmitting(true);
    try {
      await widget.onSubmit(_controller.values);
    } finally {
      if (mounted) {
        _controller.setSubmitting(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final formContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final field in widget.config.fields)
          FormBuilderField(
            config: field,
            value: _controller.values[field.name],
            errorText: _controller.errors[field.name],
            onChanged: (v) => _controller.setValue(field.name, v),
            onBlur: () => _controller.setTouched(field.name),
          ),
      ],
    );

    if (widget.modal) {
      return FormBuilderModal(
        title: widget.config.title ?? 'Form',
        onCancel: widget.onCancel ?? () => Navigator.of(context).pop(),
        onSubmit: _handleSubmit,
        submitLabel: widget.config.submitLabel,
        cancelLabel: widget.config.cancelLabel,
        isSubmitting: _controller.isSubmitting,
        child: formContent,
      );
    }

    return formContent;
  }
}
