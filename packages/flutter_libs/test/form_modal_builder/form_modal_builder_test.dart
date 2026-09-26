import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('FormModalBuilder', () {
    testWidgets('renders title and fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FormModalBuilder(
            title: 'Create Item',
            fields: const [
              FormFieldConfig(
                name: 'name',
                label: 'Name',
                type: FormFieldType.text,
                required: true,
              ),
            ],
            onSubmit: (values) async {},
          ),
        ),
      );

      expect(find.text('Create Item'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
    });

    testWidgets(
      'shows a validation error for a required empty field on submit',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: FormModalBuilder(
              title: 'Create Item',
              fields: const [
                FormFieldConfig(
                  name: 'name',
                  label: 'Name',
                  type: FormFieldType.text,
                  required: true,
                ),
              ],
              onSubmit: (values) async {},
            ),
          ),
        );

        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        expect(find.text('Name is required'), findsOneWidget);
      },
    );

    testWidgets('cancel invokes onCancel', (tester) async {
      var cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: FormModalBuilder(
            title: 'Create Item',
            fields: const [
              FormFieldConfig(
                name: 'name',
                label: 'Name',
                type: FormFieldType.text,
              ),
            ],
            onSubmit: (values) async {},
            onCancel: () => cancelled = true,
          ),
        ),
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(cancelled, isTrue);
    });

    testWidgets(
      'submits values and shows a generic error (not the raw exception) on failure',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: FormModalBuilder(
              title: 'Create Item',
              fields: const [
                FormFieldConfig(
                  name: 'name',
                  label: 'Name',
                  type: FormFieldType.text,
                ),
              ],
              onSubmit: (values) async {
                throw Exception('token=super-secret-leaked-detail');
              },
            ),
          ),
        );

        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        expect(
          find.text('Something went wrong. Please try again.'),
          findsOneWidget,
        );
        expect(find.textContaining('super-secret-leaked-detail'), findsNothing);
      },
    );

    testWidgets('successful submit passes entered values', (tester) async {
      Map<String, dynamic>? submitted;

      await tester.pumpWidget(
        MaterialApp(
          home: FormModalBuilder(
            title: 'Create Item',
            fields: const [
              FormFieldConfig(
                name: 'name',
                label: 'Name',
                type: FormFieldType.text,
              ),
            ],
            onSubmit: (values) async {
              submitted = values;
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Widget');
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(submitted?['name'], 'Widget');
    });

    testWidgets(
      'FormModalBuilder.show opens as a dialog, submits, and closes',
      (tester) async {
        Map<String, dynamic>? submitted;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => FormModalBuilder.show(
                    context: context,
                    title: 'Create Item',
                    fields: const [
                      FormFieldConfig(
                        name: 'name',
                        label: 'Name',
                        type: FormFieldType.text,
                      ),
                    ],
                    onSubmit: (values) async {
                      submitted = values;
                    },
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Create Item'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), 'Widget');
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        expect(submitted?['name'], 'Widget');
        expect(find.text('Create Item'), findsNothing);
      },
    );

    testWidgets('FormModalBuilder.show default Cancel pops the dialog', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => FormModalBuilder.show(
                  context: context,
                  title: 'Create Item',
                  fields: const [
                    FormFieldConfig(
                      name: 'name',
                      label: 'Name',
                      type: FormFieldType.text,
                    ),
                  ],
                  onSubmit: (values) async {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Create Item'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Create Item'), findsNothing);
    });

    testWidgets(
      'manual tabs group fields, auto-assign unassigned fields to the first '
      'tab, and support tab switching',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: FormModalBuilder(
              title: 'Profile',
              tabs: const [
                FormTab(id: 'basic', label: 'Basic'),
                FormTab(id: 'advanced', label: 'Advanced'),
              ],
              fields: const [
                FormFieldConfig(
                  name: 'name',
                  label: 'Name',
                  type: FormFieldType.text,
                  tab: 'basic',
                ),
                FormFieldConfig(
                  name: 'bio',
                  label: 'Bio',
                  type: FormFieldType.textarea,
                  tab: 'advanced',
                ),
                FormFieldConfig(
                  name: 'extra',
                  label: 'Extra',
                  type: FormFieldType.text,
                  defaultValue: 'preset',
                ),
              ],
              onSubmit: (values) async {},
            ),
          ),
        );

        // The unassigned "extra" field lands on the first (Basic) tab and
        // shows its defaultValue.
        expect(find.text('Basic'), findsOneWidget);
        expect(find.text('Advanced'), findsOneWidget);
        expect(find.text('Name'), findsOneWidget);
        expect(find.text('preset'), findsOneWidget);
        expect(find.text('Bio'), findsNothing);

        await tester.tap(find.text('Advanced'));
        await tester.pumpAndSettle();

        expect(find.text('Bio'), findsOneWidget);
      },
    );

    testWidgets(
      'submitting with an error on a non-active tab switches to it and '
      'shows the error badge',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: FormModalBuilder(
              title: 'Profile',
              tabs: const [
                FormTab(id: 'basic', label: 'Basic'),
                FormTab(id: 'advanced', label: 'Advanced'),
              ],
              fields: const [
                FormFieldConfig(
                  name: 'name',
                  label: 'Name',
                  type: FormFieldType.text,
                  tab: 'basic',
                ),
                FormFieldConfig(
                  name: 'bio',
                  label: 'Bio',
                  type: FormFieldType.text,
                  required: true,
                  tab: 'advanced',
                ),
              ],
              onSubmit: (values) async {},
            ),
          ),
        );

        // Starts on the Basic (first) tab; Bio lives on Advanced.
        expect(find.text('Bio'), findsNothing);

        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Bio is required'), findsOneWidget);
      },
    );

    testWidgets('auto-generates tabs when field count exceeds the threshold', (
      tester,
    ) async {
      final fields = List<FormFieldConfig>.generate(
        9,
        (i) => FormFieldConfig(
          name: 'field$i',
          label: 'Field $i',
          type: FormFieldType.text,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FormModalBuilder(
            title: 'Long Form',
            fields: fields,
            fieldsPerTab: 6,
            onSubmit: (values) async {},
          ),
        ),
      );

      expect(find.text('Page 1'), findsOneWidget);
      expect(find.text('Page 2'), findsOneWidget);
      expect(find.text('Field 0'), findsOneWidget);
      expect(find.text('Field 6'), findsNothing);

      await tester.tap(find.text('Page 2'));
      await tester.pumpAndSettle();

      expect(find.text('Field 6'), findsOneWidget);
    });
  });
}
