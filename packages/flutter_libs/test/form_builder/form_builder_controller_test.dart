import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('FormBuilderController', () {
    late FormBuilderController controller;

    setUp(() {
      controller = FormBuilderController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('starts with empty values', () {
      expect(controller.values, isEmpty);
    });

    test('starts not dirty', () {
      expect(controller.isDirty, isFalse);
    });

    test('starts not submitting', () {
      expect(controller.isSubmitting, isFalse);
    });

    test('setValue updates values and marks dirty', () {
      controller.setValue('name', 'John');
      expect(controller.values['name'], 'John');
      expect(controller.isDirty, isTrue);
    });

    test('setError sets field error', () {
      controller.setError('email', 'Required');
      expect(controller.errors['email'], 'Required');
    });

    test('isValid returns true when no errors', () {
      expect(controller.isValid, isTrue);
    });

    test('isValid returns false with errors', () {
      controller.setError('field', 'Error');
      expect(controller.isValid, isFalse);
    });

    test('setTouched marks field as touched', () {
      controller.setTouched('name');
      expect(controller.touched.containsKey('name'), isTrue);
    });

    test('setSubmitting toggles submitting state', () {
      controller.setSubmitting(true);
      expect(controller.isSubmitting, isTrue);
      controller.setSubmitting(false);
      expect(controller.isSubmitting, isFalse);
    });

    test('reset clears all state', () {
      controller.setValue('name', 'John');
      controller.setError('email', 'Required');
      controller.setTouched('name');
      controller.reset();
      expect(controller.values, isEmpty);
      expect(controller.errors, isEmpty);
      expect(controller.touched, isEmpty);
      expect(controller.isDirty, isFalse);
    });

    test('reset accepts replacement values', () {
      controller.setValue('name', 'John');
      controller.reset({'name': 'Jane'});
      expect(controller.values, {'name': 'Jane'});
      expect(controller.isDirty, isTrue);
    });

    test('setError with a null error clears an existing error', () {
      controller.setError('email', 'Required');
      expect(controller.errors['email'], 'Required');
      controller.setError('email', null);
      expect(controller.errors.containsKey('email'), isFalse);
      expect(controller.isValid, isTrue);
    });

    test('constructor seeds values from initialValues', () {
      final seeded = FormBuilderController(
        initialValues: {'name': 'Seed', 'age': 42},
      );
      expect(seeded.values, {'name': 'Seed', 'age': 42});
      seeded.dispose();
    });

    test(
      'validateAll returns true and stays empty when onValidate is null',
      () {
        expect(controller.validateAll(), isTrue);
        expect(controller.errors, isEmpty);
      },
    );

    test(
      'validateAll runs every validator, clears stale errors, and reports validity',
      () {
        final validating = FormBuilderController(
          initialValues: {'name': '', 'email': 'a@b.com'},
          onValidate: {
            'name': (dynamic v) =>
                (v == null || (v as String).isEmpty) ? 'Required' : null,
            'email': (dynamic v) =>
                (v as String).contains('@') ? null : 'Invalid email',
          },
        );
        validating.setError('stale', 'should be cleared');

        final firstPass = validating.validateAll();

        expect(firstPass, isFalse);
        expect(validating.errors['name'], 'Required');
        expect(validating.errors.containsKey('email'), isFalse);
        expect(validating.errors.containsKey('stale'), isFalse);

        validating.setValue('name', 'Jane');
        final secondPass = validating.validateAll();

        expect(secondPass, isTrue);
        expect(validating.errors, isEmpty);
        validating.dispose();
      },
    );

    test(
      'setValue triggers per-field validation when validateOnChange is true',
      () {
        final validating = FormBuilderController(
          validateOnChange: true,
          onValidate: {
            'name': (dynamic v) =>
                (v == null || (v as String).isEmpty) ? 'Required' : null,
          },
        );

        validating.setValue('name', '');
        expect(validating.errors['name'], 'Required');

        validating.setValue('name', 'Jane');
        expect(validating.errors.containsKey('name'), isFalse);
        validating.dispose();
      },
    );

    test(
      'setValue does not validate when validateOnChange is false (default)',
      () {
        final validating = FormBuilderController(
          onValidate: {'name': (dynamic v) => 'Always invalid'},
        );

        validating.setValue('name', 'anything');
        expect(validating.errors.containsKey('name'), isFalse);
        validating.dispose();
      },
    );

    test(
      'setTouched triggers per-field validation when validateOnBlur is true (default)',
      () {
        final validating = FormBuilderController(
          onValidate: {'name': (dynamic v) => 'Always invalid'},
        );

        validating.setTouched('name');
        expect(validating.errors['name'], 'Always invalid');
        validating.dispose();
      },
    );

    test('setTouched does not validate when validateOnBlur is false', () {
      final validating = FormBuilderController(
        validateOnBlur: false,
        onValidate: {'name': (dynamic v) => 'Always invalid'},
      );

      validating.setTouched('name');
      expect(validating.errors.containsKey('name'), isFalse);
      validating.dispose();
    });
  });
}
