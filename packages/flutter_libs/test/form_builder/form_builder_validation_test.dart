import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('FormBuilder Field Validation', () {
    testWidgets(
      'Required field validator shows error after submit and blocks submission',
      (WidgetTester tester) async {
        final config = FormConfig(
          title: 'Sign Up',
          fields: [
            FieldConfig(
              name: 'email',
              label: 'Email',
              type: FieldType.email,
              required: true,
              validate: (value) {
                if (value == null || (value as String).isEmpty) {
                  return 'Email is required';
                }
                return null;
              },
            ),
          ],
          submitLabel: 'Submit',
          cancelLabel: 'Cancel',
        );

        bool onSubmitCalled = false;

        await tester.pumpWidget(
          _wrap(
            FormBuilder(
              config: config,
              modal: true,
              onSubmit: (values) async {
                onSubmitCalled = true;
              },
            ),
          ),
        );

        // Try to submit with empty field
        await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
        await tester.pumpAndSettle();

        // Verify error is displayed
        expect(find.text('Email is required'), findsOneWidget);

        // Verify onSubmit was not called
        expect(onSubmitCalled, false);

        // Fill in the field
        await tester.enterText(find.byType(TextField), 'test@example.com');
        await tester.pumpAndSettle();

        // Error should clear (when validateOnChange is true, but default is false)
        // So we just verify we can submit now
        await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
        await tester.pumpAndSettle();

        expect(onSubmitCalled, true);
      },
    );

    testWidgets('Validate on change shows error while typing when enabled', (
      WidgetTester tester,
    ) async {
      final config = FormConfig(
        title: 'Profile',
        fields: [
          FieldConfig(
            name: 'name',
            label: 'Name',
            type: FieldType.text,
            validate: (value) {
              if (value == null || (value as String).length < 3) {
                return 'Name must be at least 3 characters';
              }
              return null;
            },
          ),
        ],
        validateOnChange: true,
        submitLabel: 'Submit',
        cancelLabel: 'Cancel',
      );

      await tester.pumpWidget(
        _wrap(
          FormBuilder(config: config, modal: true, onSubmit: (values) async {}),
        ),
      );

      // Type short value
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pumpAndSettle();

      // Error should be shown because validateOnChange is true
      expect(find.text('Name must be at least 3 characters'), findsOneWidget);

      // Type more characters
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pumpAndSettle();

      // Error should clear
      expect(find.text('Name must be at least 3 characters'), findsNothing);
    });

    testWidgets(
      'Validate on change does not show error while typing when disabled',
      (WidgetTester tester) async {
        final config = FormConfig(
          title: 'Profile',
          fields: [
            FieldConfig(
              name: 'name',
              label: 'Name',
              type: FieldType.text,
              validate: (value) {
                if (value == null || (value as String).length < 3) {
                  return 'Name must be at least 3 characters';
                }
                return null;
              },
            ),
          ],
          validateOnChange: false,
          submitLabel: 'Submit',
          cancelLabel: 'Cancel',
        );

        await tester.pumpWidget(
          _wrap(
            FormBuilder(
              config: config,
              modal: true,
              onSubmit: (values) async {},
            ),
          ),
        );

        // Type short value
        await tester.enterText(find.byType(TextField), 'ab');
        await tester.pumpAndSettle();

        // Error should NOT be shown because validateOnChange is false
        expect(find.text('Name must be at least 3 characters'), findsNothing);
      },
    );

    testWidgets(
      'Validate on blur shows error when field loses focus (default enabled)',
      (WidgetTester tester) async {
        final config = FormConfig(
          title: 'Profile',
          fields: [
            FieldConfig(
              name: 'name',
              label: 'Name',
              type: FieldType.text,
              validate: (value) {
                if (value == null || (value as String).length < 3) {
                  return 'Name must be at least 3 characters';
                }
                return null;
              },
            ),
          ],
          validateOnChange: false,
          validateOnBlur: true,
          submitLabel: 'Submit',
          cancelLabel: 'Cancel',
        );

        await tester.pumpWidget(
          _wrap(
            FormBuilder(
              config: config,
              modal: true,
              onSubmit: (values) async {},
            ),
          ),
        );

        // Type invalid value in the field
        await tester.enterText(find.byType(TextField), 'ab');
        await tester.pumpAndSettle();

        // Error should NOT be shown while focused (validateOnChange is false)
        expect(find.text('Name must be at least 3 characters'), findsNothing);

        // Trigger blur by simulating keyboard done action
        await tester.showKeyboard(find.byType(TextField));
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        // Error should be shown after blur (validateOnBlur is true)
        expect(find.text('Name must be at least 3 characters'), findsOneWidget);
      },
    );

    testWidgets('Validate on blur does not show error when disabled', (
      WidgetTester tester,
    ) async {
      final config = FormConfig(
        title: 'Profile',
        fields: [
          FieldConfig(
            name: 'name',
            label: 'Name',
            type: FieldType.text,
            validate: (value) {
              if (value == null || (value as String).length < 3) {
                return 'Name must be at least 3 characters';
              }
              return null;
            },
          ),
        ],
        validateOnChange: false,
        validateOnBlur: false,
        submitLabel: 'Submit',
        cancelLabel: 'Cancel',
      );

      await tester.pumpWidget(
        _wrap(
          FormBuilder(config: config, modal: true, onSubmit: (values) async {}),
        ),
      );

      // Type invalid value in the field
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.pumpAndSettle();

      // Trigger blur by simulating keyboard done action
      await tester.showKeyboard(find.byType(TextField));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Error should NOT be shown (validateOnBlur is false)
      expect(find.text('Name must be at least 3 characters'), findsNothing);
    });
  });
}
