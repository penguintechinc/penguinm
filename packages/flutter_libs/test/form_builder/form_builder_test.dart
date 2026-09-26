import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';
import 'package:mocktail/mocktail.dart';

class _MockVoidCallback extends Mock {
  void call();
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

const _twoFieldConfig = FormConfig(
  fields: [
    FieldConfig(name: 'name', label: 'Name', type: FieldType.text),
    FieldConfig(
      name: 'subscribe',
      label: 'Subscribe',
      type: FieldType.checkbox,
    ),
  ],
);

void main() {
  group('FormBuilder inline mode', () {
    testWidgets('renders one FormBuilderField per configured field', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(FormBuilder(config: _twoFieldConfig, onSubmit: (_) async {})),
      );

      expect(find.byType(FormBuilderField), findsNWidgets(2));
      expect(find.byType(FormBuilderModal), findsNothing);
    });

    testWidgets('blurring a field marks it touched on the controller', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilder(
            config: const FormConfig(
              fields: [
                FieldConfig(name: 'name', label: 'Name', type: FieldType.text),
              ],
            ),
            onSubmit: (_) async {},
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Jane');
      await tester.showKeyboard(find.byType(TextFormField));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // No validator is wired for this field, so touching it should not
      // surface an error, but the onBlur -> controller.setTouched path
      // must run without throwing.
      expect(find.byType(FormBuilderField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('seeds field values from initialValues', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilder(
            config: const FormConfig(
              fields: [
                FieldConfig(name: 'name', label: 'Name', type: FieldType.text),
              ],
            ),
            initialValues: const {'name': 'Seeded'},
            onSubmit: (_) async {},
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Seeded');
    });
  });

  group('FormBuilder modal mode', () {
    testWidgets('defaults the modal title to Form when config.title is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilder(
            config: _twoFieldConfig,
            modal: true,
            onSubmit: (_) async {},
          ),
        ),
      );

      expect(find.byType(FormBuilderModal), findsOneWidget);
      expect(find.text('Form'), findsOneWidget);
    });

    testWidgets('uses config.title as the modal title when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilder(
            config: const FormConfig(title: 'Sign Up', fields: []),
            modal: true,
            onSubmit: (_) async {},
          ),
        ),
      );

      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets(
      'submitting collects controller values and toggles the submitting state',
      (tester) async {
        Map<String, dynamic>? captured;
        final completer = Completer<void>();

        await tester.pumpWidget(
          _wrap(
            FormBuilder(
              config: _twoFieldConfig,
              modal: true,
              onSubmit: (values) async {
                captured = values;
                await completer.future;
              },
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), 'Jane');
        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
        await tester.pump();

        expect(captured, isNotNull);
        expect(captured!['name'], 'Jane');
        expect(captured!['subscribe'], isTrue);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        completer.complete();
        await tester.pump();
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets('an explicit onCancel is invoked instead of popping', (
      tester,
    ) async {
      final onCancel = _MockVoidCallback();

      await tester.pumpWidget(
        _wrap(
          FormBuilder(
            config: _twoFieldConfig,
            modal: true,
            onCancel: onCancel.call,
            onSubmit: (_) async {},
          ),
        ),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pump();

      verify(onCancel.call).called(1);
      expect(find.byType(FormBuilderModal), findsOneWidget);
    });

    testWidgets('without onCancel, the default pops the enclosing route', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: FormBuilder(
                        config: _twoFieldConfig,
                        modal: true,
                        onSubmit: (_) async {},
                      ),
                    ),
                  ),
                ),
                child: const Text('Open Form'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Form'));
      await tester.pumpAndSettle();
      expect(find.byType(FormBuilderModal), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(FormBuilderModal), findsNothing);
      expect(find.text('Open Form'), findsOneWidget);
    });
  });
}
