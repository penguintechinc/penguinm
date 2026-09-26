import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';
import 'package:mocktail/mocktail.dart';

class _MockValueChanged extends Mock {
  void call(dynamic value);
}

class _MockVoidCallback extends Mock {
  void call();
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  group('FormBuilderField label, helper and error text', () {
    testWidgets('shows the label and hides the required marker by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'name',
              label: 'Name',
              type: FieldType.text,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Name'), findsOneWidget);
      expect(find.text(' *'), findsNothing);
    });

    testWidgets('shows a required marker when config.required is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'name',
              label: 'Name',
              type: FieldType.text,
              required: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text(' *'), findsOneWidget);
    });

    testWidgets('shows helper text when there is no error', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'name',
              label: 'Name',
              type: FieldType.text,
              helperText: 'Full legal name',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Full legal name'), findsOneWidget);
    });

    testWidgets('shows error text instead of helper text when both are set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'name',
              label: 'Name',
              type: FieldType.text,
              helperText: 'Full legal name',
            ),
            value: null,
            errorText: 'Name is required',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Full legal name'), findsNothing);
      expect(find.text('Name is required'), findsOneWidget);
    });
  });

  group('FormBuilderField text-like inputs', () {
    for (final type in [
      FieldType.text,
      FieldType.email,
      FieldType.number,
      FieldType.tel,
      FieldType.url,
      FieldType.datetimeLocal,
    ]) {
      testWidgets('renders a TextFormField for $type', (tester) async {
        final onChanged = _MockValueChanged();
        await tester.pumpWidget(
          _wrap(
            FormBuilderField(
              config: FieldConfig(name: 'f', label: 'F', type: type),
              value: 'initial',
              onChanged: onChanged.call,
            ),
          ),
        );

        expect(find.byType(TextFormField), findsOneWidget);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.controller!.text, 'initial');
        expect(field.obscureText, isFalse);

        await tester.enterText(find.byType(TextFormField), 'typed');
        verify(() => onChanged.call('typed')).called(1);
      });
    }

    testWidgets('obscures text for password fields', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'pw',
              label: 'Password',
              type: FieldType.password,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, isTrue);
    });

    testWidgets('disables the field when config.disabled is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'f',
              label: 'F',
              type: FieldType.text,
              disabled: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });

    testWidgets('autofocuses when config.autoFocus is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'f',
              label: 'F',
              type: FieldType.text,
              autoFocus: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);
    });

    testWidgets('shows the configured placeholder as hint text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'f',
              label: 'F',
              type: FieldType.text,
              placeholder: 'Type here',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration?.hintText, 'Type here');
    });

    testWidgets('calls onBlur when editing completes', (tester) async {
      final onBlur = _MockVoidCallback();
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'f',
              label: 'F',
              type: FieldType.text,
            ),
            value: null,
            onChanged: (_) {},
            onBlur: onBlur.call,
          ),
        ),
      );

      await tester.showKeyboard(find.byType(TextFormField));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      verify(onBlur.call).called(1);
    });

    group('keyboard type mapping', () {
      final expectations = <FieldType, TextInputType>{
        FieldType.text: TextInputType.text,
        FieldType.password: TextInputType.text,
        FieldType.datetimeLocal: TextInputType.text,
        FieldType.email: TextInputType.emailAddress,
        FieldType.number: TextInputType.number,
        FieldType.tel: TextInputType.phone,
        FieldType.url: TextInputType.url,
      };

      expectations.forEach((type, expected) {
        testWidgets('$type maps to $expected', (tester) async {
          await tester.pumpWidget(
            _wrap(
              FormBuilderField(
                config: FieldConfig(name: 'f', label: 'F', type: type),
                value: null,
                onChanged: (_) {},
              ),
            ),
          );

          final editable = tester.widget<EditableText>(
            find.byType(EditableText),
          );
          expect(editable.keyboardType, expected);
        });
      });
    });
  });

  group('FormBuilderField textarea', () {
    testWidgets('defaults to 4 rows when config.rows is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'bio',
              label: 'Bio',
              type: FieldType.textarea,
            ),
            value: 'hello',
            onChanged: (_) {},
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, 4);
      expect(field.controller!.text, 'hello');
    });

    testWidgets('uses config.rows when provided', (tester) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'bio',
              label: 'Bio',
              type: FieldType.textarea,
              rows: 8,
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, 8);

      await tester.enterText(find.byType(TextFormField), 'notes');
      verify(() => onChanged.call('notes')).called(1);
    });
  });

  group('FormBuilderField dropdown', () {
    const options = [
      SelectOption(value: 'us', label: 'United States'),
      SelectOption(value: 'ca', label: 'Canada'),
    ];

    testWidgets('renders every option and reflects the initial value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'country',
              label: 'Country',
              type: FieldType.select,
              options: options,
            ),
            value: 'us',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.text('United States'), findsOneWidget);
    });

    testWidgets('selecting an option invokes onChanged', (tester) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'country',
              label: 'Country',
              type: FieldType.select,
              options: options,
            ),
            value: 'us',
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Canada').last);
      await tester.pumpAndSettle();

      verify(() => onChanged.call('ca')).called(1);
    });

    testWidgets('disables selection when config.disabled is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'country',
              label: 'Country',
              type: FieldType.select,
              options: options,
              disabled: true,
            ),
            value: 'us',
            onChanged: (_) {},
          ),
        ),
      );

      final dropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(dropdown.onChanged, isNull);
    });

    testWidgets('renders without options', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'country',
              label: 'Country',
              type: FieldType.select,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });
  });

  group('FormBuilderField checkbox', () {
    testWidgets('reflects an unchecked value and toggles on tap', (
      tester,
    ) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'agree',
              label: 'I agree',
              type: FieldType.checkbox,
            ),
            value: false,
            onChanged: onChanged.call,
          ),
        ),
      );

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isFalse);

      await tester.tap(find.byType(Checkbox));
      verify(() => onChanged.call(true)).called(1);
    });

    testWidgets('reflects a checked value', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'agree',
              label: 'I agree',
              type: FieldType.checkbox,
            ),
            value: true,
            onChanged: (_) {},
          ),
        ),
      );

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('disables the checkbox when config.disabled is true', (
      tester,
    ) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'agree',
              label: 'I agree',
              type: FieldType.checkbox,
              disabled: true,
            ),
            value: false,
            onChanged: onChanged.call,
          ),
        ),
      );

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.onChanged, isNull);
    });
  });

  group('FormBuilderField radio group', () {
    const options = [
      SelectOption(value: 'm', label: 'Male'),
      SelectOption(value: 'f', label: 'Female'),
    ];

    testWidgets('renders a tile per option and reflects the group value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'gender',
              label: 'Gender',
              type: FieldType.radio,
              options: options,
            ),
            value: 'm',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(RadioListTile<String>), findsNWidgets(2));
      final radioGroup = tester.widget<RadioGroup<String>>(
        find.byType(RadioGroup<String>),
      );
      expect(radioGroup.groupValue, 'm');
    });

    testWidgets('selecting an option invokes onChanged', (tester) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'gender',
              label: 'Gender',
              type: FieldType.radio,
              options: options,
            ),
            value: 'm',
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.tap(find.widgetWithText(RadioListTile<String>, 'Female'));
      await tester.pump();

      verify(() => onChanged.call('f')).called(1);
    });

    testWidgets('renders no tiles when there are no options', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'gender',
              label: 'Gender',
              type: FieldType.radio,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(RadioGroup<String>), findsOneWidget);
      expect(find.byType(RadioListTile<String>), findsNothing);
    });

    testWidgets('disables every tile when config.disabled is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'gender',
              label: 'Gender',
              type: FieldType.radio,
              options: options,
              disabled: true,
            ),
            value: 'm',
            onChanged: (_) {},
          ),
        ),
      );

      final tile = tester.widget<RadioListTile<String>>(
        find.byType(RadioListTile<String>).first,
      );
      expect(tile.enabled, isFalse);
    });
  });

  group('FormBuilderField date', () {
    testWidgets('renders a text field with a calendar icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'dob',
              label: 'Date of Birth',
              type: FieldType.date,
            ),
            value: '2024-01-01',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '2024-01-01');
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('disables the field when config.disabled is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'dob',
              label: 'Date of Birth',
              type: FieldType.date,
              disabled: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });

    testWidgets('selecting a day invokes onChanged with an ISO date string', (
      tester,
    ) async {
      dynamic changedValue;
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'dob',
              label: 'Date of Birth',
              type: FieldType.date,
            ),
            value: null,
            onChanged: (v) => changedValue = v,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();

      final today = DateTime.now();
      await tester.tap(find.text(today.day.toString()).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(
        changedValue,
        DateTime(
          today.year,
          today.month,
          today.day,
        ).toIso8601String().split('T').first,
      );
    });

    testWidgets('typing into the date text field invokes onChanged directly', (
      tester,
    ) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'dob',
              label: 'Date of Birth',
              type: FieldType.date,
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '2024-05-01');

      verify(() => onChanged.call('2024-05-01')).called(1);
    });

    testWidgets('cancelling the picker does not invoke onChanged', (
      tester,
    ) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'dob',
              label: 'Date of Birth',
              type: FieldType.date,
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.calendar_today));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => onChanged.call(any<dynamic>()));
    });
  });

  group('FormBuilderField time', () {
    testWidgets('renders a text field with a clock icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'start',
              label: 'Start Time',
              type: FieldType.time,
            ),
            value: '09:00',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '09:00');
      expect(find.byIcon(Icons.access_time), findsOneWidget);
    });

    testWidgets('disables the field when config.disabled is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'start',
              label: 'Start Time',
              type: FieldType.time,
              disabled: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
    });

    testWidgets(
      'confirming a time invokes onChanged with a zero-padded HH:mm string',
      (tester) async {
        dynamic changedValue;
        await tester.pumpWidget(
          _wrap(
            FormBuilderField(
              config: const FieldConfig(
                name: 'start',
                label: 'Start Time',
                type: FieldType.time,
              ),
              value: null,
              onChanged: (v) => changedValue = v,
            ),
          ),
        );

        await tester.tap(find.byIcon(Icons.access_time));
        await tester.pumpAndSettle();

        // Switch from the dial to text-input entry mode so the hour and
        // minute can be set deterministically without simulating clock
        // drags.
        await tester.tap(find.byIcon(Icons.keyboard_outlined));
        await tester.pumpAndSettle();

        final timeFields = find.descendant(
          of: find.byType(Dialog),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(timeFields.at(0), '09');
        await tester.enterText(timeFields.at(1), '30');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(changedValue, isNotNull);
        expect(changedValue, matches(RegExp(r'^\d{2}:\d{2}$')));
      },
    );

    testWidgets('typing into the time text field invokes onChanged directly', (
      tester,
    ) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'start',
              label: 'Start Time',
              type: FieldType.time,
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), '09:30');

      verify(() => onChanged.call('09:30')).called(1);
    });

    testWidgets('cancelling the picker does not invoke onChanged', (
      tester,
    ) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormBuilderField(
            config: const FieldConfig(
              name: 'start',
              label: 'Start Time',
              type: FieldType.time,
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.access_time));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => onChanged.call(any<dynamic>()));
    });
  });
}
