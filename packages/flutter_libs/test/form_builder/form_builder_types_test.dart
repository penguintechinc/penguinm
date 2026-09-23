import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('FieldType', () {
    test('enumerates every field type the field builder must handle', () {
      expect(FieldType.values, hasLength(13));
      expect(
        FieldType.values,
        containsAll(<FieldType>[
          FieldType.text,
          FieldType.email,
          FieldType.password,
          FieldType.number,
          FieldType.textarea,
          FieldType.select,
          FieldType.checkbox,
          FieldType.radio,
          FieldType.date,
          FieldType.time,
          FieldType.datetimeLocal,
          FieldType.tel,
          FieldType.url,
        ]),
      );
    });
  });

  group('SelectOption', () {
    test('stores value and label', () {
      const option = SelectOption(value: 'opt-1', label: 'Option One');
      expect(option.value, 'opt-1');
      expect(option.label, 'Option One');
    });

    test('constructing without const runs the constructor at runtime', () {
      // Every other SelectOption construction in this suite (here and in
      // form_builder_field_test.dart) is `const` and gets compile-time
      // folded, so lcov never sees the constructor body execute. A
      // runtime-only value (read from a variable) forces a genuine call.
      final value = 'opt-1';
      final label = 'Option One';
      final option = SelectOption(value: value, label: label);
      expect(option.value, 'opt-1');
      expect(option.label, 'Option One');
    });
  });

  group('FieldConfig', () {
    test('applies defaults when only required fields are given', () {
      const config = FieldConfig(
        name: 'email',
        label: 'Email',
        type: FieldType.email,
      );

      expect(config.name, 'email');
      expect(config.label, 'Email');
      expect(config.type, FieldType.email);
      expect(config.placeholder, isNull);
      expect(config.required, isFalse);
      expect(config.disabled, isFalse);
      expect(config.autoFocus, isFalse);
      expect(config.min, isNull);
      expect(config.max, isNull);
      expect(config.minLength, isNull);
      expect(config.maxLength, isNull);
      expect(config.pattern, isNull);
      expect(config.step, isNull);
      expect(config.rows, isNull);
      expect(config.options, isNull);
      expect(config.helperText, isNull);
      expect(config.validate, isNull);
      expect(config.onChange, isNull);
    });

    test('stores every optional field when provided', () {
      String? validateResult(dynamic value) =>
          value == null ? 'Required' : null;
      var changeCount = 0;
      void onChange(dynamic value) => changeCount++;

      final config = FieldConfig(
        name: 'age',
        label: 'Age',
        type: FieldType.number,
        placeholder: 'Enter age',
        required: true,
        disabled: true,
        autoFocus: true,
        min: 0,
        max: 120,
        minLength: 1,
        maxLength: 3,
        pattern: r'^\d+$',
        step: 1,
        rows: 4,
        options: const [SelectOption(value: 'a', label: 'A')],
        helperText: 'Whole years only',
        validate: validateResult,
        onChange: onChange,
      );

      expect(config.placeholder, 'Enter age');
      expect(config.required, isTrue);
      expect(config.disabled, isTrue);
      expect(config.autoFocus, isTrue);
      expect(config.min, 0);
      expect(config.max, 120);
      expect(config.minLength, 1);
      expect(config.maxLength, 3);
      expect(config.pattern, r'^\d+$');
      expect(config.step, 1);
      expect(config.rows, 4);
      expect(config.options, hasLength(1));
      expect(config.options!.first.value, 'a');
      expect(config.helperText, 'Whole years only');
      expect(config.validate!(null), 'Required');
      expect(config.validate!('42'), isNull);
      config.onChange!('42');
      expect(changeCount, 1);
    });
  });

  group('FormConfig', () {
    test('applies defaults when only fields are given', () {
      const formConfig = FormConfig(fields: []);

      expect(formConfig.fields, isEmpty);
      expect(formConfig.title, isNull);
      expect(formConfig.submitLabel, 'Submit');
      expect(formConfig.cancelLabel, 'Cancel');
      expect(formConfig.validateOnChange, isFalse);
      expect(formConfig.validateOnBlur, isTrue);
    });

    test('stores every optional field when provided', () {
      const fields = [
        FieldConfig(name: 'name', label: 'Name', type: FieldType.text),
      ];
      const formConfig = FormConfig(
        fields: fields,
        title: 'Contact Us',
        submitLabel: 'Send',
        cancelLabel: 'Dismiss',
        validateOnChange: true,
        validateOnBlur: false,
      );

      expect(formConfig.fields, fields);
      expect(formConfig.title, 'Contact Us');
      expect(formConfig.submitLabel, 'Send');
      expect(formConfig.cancelLabel, 'Dismiss');
      expect(formConfig.validateOnChange, isTrue);
      expect(formConfig.validateOnBlur, isFalse);
    });
  });
}
