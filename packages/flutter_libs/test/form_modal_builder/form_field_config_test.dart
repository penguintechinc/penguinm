import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('FormFieldType', () {
    test('has all 18 supported values', () {
      expect(FormFieldType.values.length, 18);
      expect(FormFieldType.values, contains(FormFieldType.text));
      expect(FormFieldType.values, contains(FormFieldType.email));
      expect(FormFieldType.values, contains(FormFieldType.password));
      expect(FormFieldType.values, contains(FormFieldType.passwordGenerate));
      expect(FormFieldType.values, contains(FormFieldType.number));
      expect(FormFieldType.values, contains(FormFieldType.tel));
      expect(FormFieldType.values, contains(FormFieldType.url));
      expect(FormFieldType.values, contains(FormFieldType.textarea));
      expect(FormFieldType.values, contains(FormFieldType.multiline));
      expect(FormFieldType.values, contains(FormFieldType.select));
      expect(FormFieldType.values, contains(FormFieldType.checkbox));
      expect(FormFieldType.values, contains(FormFieldType.checkboxMulti));
      expect(FormFieldType.values, contains(FormFieldType.radio));
      expect(FormFieldType.values, contains(FormFieldType.date));
      expect(FormFieldType.values, contains(FormFieldType.time));
      expect(FormFieldType.values, contains(FormFieldType.datetimeLocal));
      expect(FormFieldType.values, contains(FormFieldType.file));
      expect(FormFieldType.values, contains(FormFieldType.fileMultiple));
    });
  });

  group('FormFieldOption', () {
    test('stores value and label', () {
      // Deliberately not `const`: a const invocation is folded at compile
      // time and never executes the constructor body at runtime, so lcov
      // never sees it as covered. Runtime-only values (read from a
      // variable, not literals in a const context) force a real call.
      final value = 'a';
      final label = 'Option A';
      final opt = FormFieldOption(value: value, label: label);
      expect(opt.value, 'a');
      expect(opt.label, 'Option A');
    });

    test('value accepts non-string dynamic types', () {
      final value = 42;
      final label = 'Forty Two';
      final opt = FormFieldOption(value: value, label: label);
      expect(opt.value, 42);
    });
  });

  group('FormFieldConfig', () {
    test('applies defaults when only required fields are given', () {
      final name = 'email';
      final type = FormFieldType.email;
      final label = 'Email';
      final config = FormFieldConfig(name: name, type: type, label: label);

      expect(config.name, 'email');
      expect(config.type, FormFieldType.email);
      expect(config.label, 'Email');
      expect(config.description, isNull);
      expect(config.helpText, isNull);
      expect(config.defaultValue, isNull);
      expect(config.placeholder, isNull);
      expect(config.required, isFalse);
      expect(config.disabled, isFalse);
      expect(config.hidden, isFalse);
      expect(config.options, isNull);
      expect(config.min, isNull);
      expect(config.max, isNull);
      expect(config.pattern, isNull);
      expect(config.accept, isNull);
      expect(config.rows, isNull);
      expect(config.triggerField, isNull);
      expect(config.showWhen, isNull);
      expect(config.onPasswordGenerated, isNull);
      expect(config.maxFileSize, isNull);
      expect(config.maxFiles, isNull);
      expect(config.tab, isNull);
    });

    test('accepts every optional field', () {
      var generatedPassword = '';
      final name = 'password';
      final type = FormFieldType.passwordGenerate;
      final label = 'Password';
      final description = 'A strong password';
      final helpText = 'Minimum 8 characters';
      final defaultValue = 'default';
      final placeholder = 'Enter password';
      final pattern = r'^[a-z]+$';
      final accept = '.png,.jpg';
      final tab = 'security';
      final triggerField = 'otherField';

      final config = FormFieldConfig(
        name: name,
        type: type,
        label: label,
        description: description,
        helpText: helpText,
        defaultValue: defaultValue,
        placeholder: placeholder,
        required: true,
        disabled: true,
        hidden: true,
        options: const [FormFieldOption(value: 'a', label: 'A')],
        min: 1,
        max: 100,
        pattern: pattern,
        accept: accept,
        rows: 5,
        triggerField: triggerField,
        showWhen: (values) => values['otherField'] == 'yes',
        onPasswordGenerated: (pw) => generatedPassword = pw,
        maxFileSize: 1024,
        maxFiles: 3,
        tab: tab,
      );

      expect(config.description, 'A strong password');
      expect(config.helpText, 'Minimum 8 characters');
      expect(config.defaultValue, 'default');
      expect(config.placeholder, 'Enter password');
      expect(config.required, isTrue);
      expect(config.disabled, isTrue);
      expect(config.hidden, isTrue);
      expect(config.options, hasLength(1));
      expect(config.min, 1);
      expect(config.max, 100);
      expect(config.pattern, r'^[a-z]+$');
      expect(config.accept, '.png,.jpg');
      expect(config.rows, 5);
      expect(config.triggerField, 'otherField');
      expect(config.showWhen!({'otherField': 'yes'}), isTrue);
      expect(config.showWhen!({'otherField': 'no'}), isFalse);
      config.onPasswordGenerated!('secret123');
      expect(generatedPassword, 'secret123');
      expect(config.maxFileSize, 1024);
      expect(config.maxFiles, 3);
      expect(config.tab, 'security');
    });
  });
}
