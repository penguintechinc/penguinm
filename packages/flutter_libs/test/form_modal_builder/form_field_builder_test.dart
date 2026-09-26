import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';
import 'package:mocktail/mocktail.dart';

class _MockValueChanged extends Mock {
  void call(dynamic value);
}

/// A fully in-memory [FilePickerPlatform] double for testing file picker behavior.
class _FakeFilePickerPlatform extends FilePickerPlatform {
  _FakeFilePickerPlatform({this.singleResult, this.multiResult = const []});

  final PlatformFile? singleResult;
  final List<PlatformFile> multiResult;

  bool pickFileCalled = false;
  bool pickFilesCalled = false;
  FileType? capturedType;
  List<String>? capturedExtensions;

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    pickFileCalled = true;
    capturedType = type;
    capturedExtensions = allowedExtensions;
    return singleResult;
  }

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    void Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    pickFilesCalled = true;
    capturedType = type;
    capturedExtensions = allowedExtensions;
    return multiResult;
  }
}

/// A minimal [PlatformFile] double exposing only [name] — the only member
/// [FormFieldBuilder]'s file-field callbacks read from a pick result.
///
/// [PlatformFile] is declared `abstract base class`, so a concrete double
/// must `extends` it from within this library; overriding [noSuchMethod]
/// lets it stand in for the other abstract members ([uri], [xFile], etc.)
/// without needing a direct dependency on `package:cross_file` (a
/// transitive dependency only) just to spell their types.
base class _FakePlatformFile extends PlatformFile {
  _FakePlatformFile(this.name);

  @override
  final String name;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    '${invocation.memberName} is not used by FormFieldBuilder',
  );
}

material.Widget _wrap(material.Widget child) => material.MaterialApp(
  home: material.Scaffold(body: material.SingleChildScrollView(child: child)),
);

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  group('FormFieldBuilder basic properties', () {
    testWidgets('renders nothing when hidden is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.text,
              label: 'Hidden field',
              hidden: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Hidden field'), findsNothing);
      expect(find.byType(material.TextFormField), findsNothing);
    });

    testWidgets('shows the label and required marker when required', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.text,
              label: 'Name',
              required: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Name'), findsOneWidget);
      expect(find.text(' *'), findsOneWidget);
    });

    testWidgets('shows description when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.text,
              label: 'Name',
              description: 'Your full legal name',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Your full legal name'), findsOneWidget);
    });

    testWidgets('shows help text when no error', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.text,
              label: 'Name',
              helpText: 'Enter as it appears on your ID',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Enter as it appears on your ID'), findsOneWidget);
    });

    testWidgets('shows error text and hides help text when error', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.text,
              label: 'Name',
              helpText: 'Enter as it appears on your ID',
            ),
            value: null,
            onChanged: (_) {},
            errorText: 'Name is required',
          ),
        ),
      );

      expect(find.text('Name is required'), findsOneWidget);
      expect(find.text('Enter as it appears on your ID'), findsNothing);
    });
  });

  group('FormFieldBuilder text field types', () {
    for (final type in [
      FormFieldType.text,
      FormFieldType.email,
      FormFieldType.tel,
      FormFieldType.url,
      FormFieldType.number,
    ]) {
      testWidgets('renders TextFormField for $type', (tester) async {
        final onChanged = _MockValueChanged();
        await tester.pumpWidget(
          _wrap(
            FormFieldBuilder(
              field: FormFieldConfig(name: 'f', type: type, label: 'Field'),
              value: null,
              onChanged: onChanged.call,
            ),
          ),
        );

        expect(find.byType(material.TextFormField), findsOneWidget);
        await tester.enterText(find.byType(material.TextFormField), '123');
        verify(() => onChanged.call('123')).called(1);
      });
    }

    testWidgets('filters non-numeric characters for number fields', (
      tester,
    ) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.number,
              label: 'Amount',
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.enterText(find.byType(material.TextFormField), 'a1b2c3');
      verify(() => onChanged.call('123')).called(1);
    });

    testWidgets('uses initial value when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.text,
              label: 'Name',
            ),
            value: 'Existing',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Existing'), findsOneWidget);
    });

    testWidgets('uses defaultValue when value is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.text,
              label: 'Name',
              defaultValue: 'Default Name',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Default Name'), findsOneWidget);
    });

    testWidgets('disables field when disabled is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.text,
              label: 'Name',
              disabled: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final widget = tester.widget<material.TextFormField>(
        find.byType(material.TextFormField),
      );
      expect(widget.enabled, isFalse);
    });
  });

  group('FormFieldBuilder password field', () {
    testWidgets('renders obscured TextFormField', (tester) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.password,
              label: 'Password',
            ),
            value: 'secret',
            onChanged: onChanged.call,
          ),
        ),
      );

      expect(find.byType(material.TextFormField), findsOneWidget);
      await tester.enterText(find.byType(material.TextFormField), 'newsecret');
      verify(() => onChanged.call('newsecret')).called(1);
    });

    testWidgets('disables when disabled is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.password,
              label: 'Password',
              disabled: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final widget = tester.widget<material.TextFormField>(
        find.byType(material.TextFormField),
      );
      expect(widget.enabled, isFalse);
    });
  });

  group('FormFieldBuilder password-generate field', () {
    testWidgets('generates password on button tap', (tester) async {
      final onChanged = _MockValueChanged();
      String? generated;
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: FormFieldConfig(
              name: 'f',
              type: FormFieldType.passwordGenerate,
              label: 'Password',
              onPasswordGenerated: (pw) => generated = pw,
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.tap(find.byIcon(material.Icons.refresh));
      await tester.pump();

      expect(generated, isNotNull);
      expect(generated!.length, 14);
    });

    testWidgets('disables button when disabled', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.passwordGenerate,
              label: 'Password',
              disabled: true,
            ),
            value: 'existing',
            onChanged: (_) {},
          ),
        ),
      );

      final button = tester.widget<material.IconButton>(
        find.byType(material.IconButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('typing invokes onChanged', (tester) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.passwordGenerate,
              label: 'Password',
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.enterText(find.byType(material.TextFormField), 'Secret1!');

      verify(() => onChanged.call('Secret1!')).called(1);
    });
  });

  group('FormFieldBuilder textarea', () {
    testWidgets('emits plain string for textarea', (tester) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.textarea,
              label: 'Bio',
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.enterText(
        find.byType(material.TextFormField),
        'line1\nline2',
      );
      verify(() => onChanged.call('line1\nline2')).called(1);
    });

    testWidgets('splits multiline input into filtered list', (tester) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.multiline,
              label: 'Lines',
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.enterText(find.byType(material.TextFormField), 'a\n\nb');
      verify(() => onChanged.call(['a', 'b'])).called(1);
    });

    testWidgets('uses field.rows for maxLines', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.textarea,
              label: 'Bio',
              rows: 8,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(material.TextFormField), findsOneWidget);
    });

    testWidgets('uses defaultValue when value is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.textarea,
              label: 'Bio',
              defaultValue: 'Default bio',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Default bio'), findsOneWidget);
    });
  });

  group('FormFieldBuilder dropdown', () {
    testWidgets('renders options and handles selection', (tester) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: FormFieldConfig(
              name: 'f',
              type: FormFieldType.select,
              label: 'Role',
              options: const [
                FormFieldOption(value: 'a', label: 'Option A'),
                FormFieldOption(value: 'b', label: 'Option B'),
              ],
            ),
            value: 'a',
            onChanged: onChanged.call,
          ),
        ),
      );

      expect(
        find.byType(material.DropdownButtonFormField<dynamic>),
        findsOneWidget,
      );

      await tester.tap(find.byType(material.DropdownButtonFormField<dynamic>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Option B').last);
      await tester.pumpAndSettle();

      verify(() => onChanged.call('b')).called(1);
    });

    testWidgets('uses defaultValue when value is null', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.select,
              label: 'Role',
              defaultValue: 'b',
              options: [
                FormFieldOption(value: 'a', label: 'Option A'),
                FormFieldOption(value: 'b', label: 'Option B'),
              ],
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final widget = tester.widget<material.DropdownButtonFormField<dynamic>>(
        find.byType(material.DropdownButtonFormField<dynamic>),
      );
      expect(widget.initialValue, 'b');
    });

    testWidgets('renders with no options', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.select,
              label: 'Role',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(
        find.byType(material.DropdownButtonFormField<dynamic>),
        findsOneWidget,
      );
    });

    testWidgets('disables when disabled is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.select,
              label: 'Role',
              disabled: true,
              options: [FormFieldOption(value: 'a', label: 'Option A')],
            ),
            value: 'a',
            onChanged: (_) {},
          ),
        ),
      );

      final widget = tester.widget<material.DropdownButtonFormField<dynamic>>(
        find.byType(material.DropdownButtonFormField<dynamic>),
      );
      expect(widget.onChanged, isNull);
    });
  });

  group('FormFieldBuilder checkbox', () {
    testWidgets('is checked when value is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.checkbox,
              label: 'Accept',
            ),
            value: true,
            onChanged: (_) {},
          ),
        ),
      );

      final checkbox = tester.widget<material.Checkbox>(
        find.byType(material.Checkbox),
      );
      expect(checkbox.value, isTrue);
    });

    testWidgets("is checked when value is string 'true'", (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.checkbox,
              label: 'Accept',
            ),
            value: 'true',
            onChanged: (_) {},
          ),
        ),
      );

      final checkbox = tester.widget<material.Checkbox>(
        find.byType(material.Checkbox),
      );
      expect(checkbox.value, isTrue);
    });

    testWidgets('is unchecked for null values', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.checkbox,
              label: 'Accept',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final checkbox = tester.widget<material.Checkbox>(
        find.byType(material.Checkbox),
      );
      expect(checkbox.value, isFalse);
    });

    testWidgets('toggles via onChanged on tap', (tester) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.checkbox,
              label: 'Accept',
            ),
            value: false,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.tap(find.byType(material.Checkbox));
      verify(() => onChanged.call(true)).called(1);
    });

    testWidgets('disables when disabled is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.checkbox,
              label: 'Accept',
              disabled: true,
            ),
            value: false,
            onChanged: (_) {},
          ),
        ),
      );

      final checkbox = tester.widget<material.Checkbox>(
        find.byType(material.Checkbox),
      );
      expect(checkbox.onChanged, isNull);
    });
  });

  group('FormFieldBuilder checkbox-multi', () {
    testWidgets('marks selected options as checked', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.checkboxMulti,
              label: 'Tags',
              options: [
                FormFieldOption(value: 'a', label: 'Tag A'),
                FormFieldOption(value: 'b', label: 'Tag B'),
              ],
            ),
            value: const ['a'],
            onChanged: (_) {},
          ),
        ),
      );

      final tiles = tester
          .widgetList<material.CheckboxListTile>(
            find.byType(material.CheckboxListTile),
          )
          .toList();
      expect(tiles[0].value, isTrue);
      expect(tiles[1].value, isFalse);
    });

    testWidgets('treats non-list value as no selection', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.checkboxMulti,
              label: 'Tags',
              options: [FormFieldOption(value: 'a', label: 'Tag A')],
            ),
            value: 'not-a-list',
            onChanged: (_) {},
          ),
        ),
      );

      final tile = tester.widget<material.CheckboxListTile>(
        find.byType(material.CheckboxListTile),
      );
      expect(tile.value, isFalse);
    });

    testWidgets('adds value on unchecked option tap', (tester) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.checkboxMulti,
              label: 'Tags',
              options: [
                FormFieldOption(value: 'a', label: 'Tag A'),
                FormFieldOption(value: 'b', label: 'Tag B'),
              ],
            ),
            value: const ['a'],
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.tap(find.text('Tag B'));
      verify(() => onChanged.call(['a', 'b'])).called(1);
    });

    testWidgets('removes value on checked option tap', (tester) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.checkboxMulti,
              label: 'Tags',
              options: [
                FormFieldOption(value: 'a', label: 'Tag A'),
                FormFieldOption(value: 'b', label: 'Tag B'),
              ],
            ),
            value: const ['a', 'b'],
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.tap(find.text('Tag A'));
      verify(() => onChanged.call(['b'])).called(1);
    });

    testWidgets('disables all tiles when disabled is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.checkboxMulti,
              label: 'Tags',
              disabled: true,
              options: [FormFieldOption(value: 'a', label: 'Tag A')],
            ),
            value: const ['a'],
            onChanged: (_) {},
          ),
        ),
      );

      final tile = tester.widget<material.CheckboxListTile>(
        find.byType(material.CheckboxListTile),
      );
      expect(tile.onChanged, isNull);
    });

    testWidgets('renders with no options', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.checkboxMulti,
              label: 'Tags',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(material.CheckboxListTile), findsNothing);
    });
  });

  group('FormFieldBuilder radio group', () {
    testWidgets('invokes onChanged on selection', (tester) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.radio,
              label: 'Plan',
              options: [
                FormFieldOption(value: 'free', label: 'Free'),
                FormFieldOption(value: 'pro', label: 'Pro'),
              ],
            ),
            value: 'free',
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.tap(find.text('Pro'));
      verify(() => onChanged.call('pro')).called(1);
    });

    testWidgets('disables tiles when disabled is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.radio,
              label: 'Plan',
              disabled: true,
              options: [FormFieldOption(value: 'free', label: 'Free')],
            ),
            value: 'free',
            onChanged: (_) {},
          ),
        ),
      );

      final tile = tester.widget<material.RadioListTile<dynamic>>(
        find.byType(material.RadioListTile<dynamic>),
      );
      expect(tile.enabled, isFalse);
    });

    testWidgets('renders with no options', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.radio,
              label: 'Plan',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(material.RadioListTile<dynamic>), findsNothing);
    });
  });

  group('FormFieldBuilder date field', () {
    testWidgets('renders calendar icon and value', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.date,
              label: 'Birthday',
            ),
            value: '2024-01-01',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byIcon(material.Icons.calendar_today), findsOneWidget);
      expect(find.text('2024-01-01'), findsOneWidget);
    });

    testWidgets('typing invokes onChanged', (tester) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.date,
              label: 'Birthday',
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.enterText(find.byType(material.TextFormField), '2024-05-01');
      verify(() => onChanged.call('2024-05-01')).called(1);
    });

    testWidgets('disables picker when disabled is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.date,
              label: 'Birthday',
              disabled: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final button = tester.widget<material.IconButton>(
        find.byType(material.IconButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('selecting a date via the picker invokes onChanged', (
      tester,
    ) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.date,
              label: 'Birthday',
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.tap(find.byIcon(material.Icons.calendar_today));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final captured =
          verify(() => onChanged.call(captureAny<dynamic>())).captured.single
              as String;
      expect(captured, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });
  });

  group('FormFieldBuilder time field', () {
    testWidgets('renders clock icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.time,
              label: 'Start time',
            ),
            value: '09:30',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byIcon(material.Icons.access_time), findsOneWidget);
      expect(find.text('09:30'), findsOneWidget);
    });

    testWidgets('typing invokes onChanged', (tester) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.time,
              label: 'Start time',
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.enterText(find.byType(material.TextFormField), '10:15');
      verify(() => onChanged.call('10:15')).called(1);
    });

    testWidgets('disables picker when disabled is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.time,
              label: 'Start time',
              disabled: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final button = tester.widget<material.IconButton>(
        find.byType(material.IconButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('selecting a time via the picker invokes onChanged', (
      tester,
    ) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.time,
              label: 'Start time',
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.tap(find.byIcon(material.Icons.access_time));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final captured =
          verify(() => onChanged.call(captureAny<dynamic>())).captured.single
              as String;
      expect(captured, matches(RegExp(r'^\d{2}:\d{2}$')));
    });
  });

  group('FormFieldBuilder datetimeLocal field', () {
    testWidgets('renders event icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.datetimeLocal,
              label: 'Appointment',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byIcon(material.Icons.event), findsOneWidget);
    });

    testWidgets('typing invokes onChanged', (tester) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.datetimeLocal,
              label: 'Appointment',
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.enterText(
        find.byType(material.TextFormField),
        '2024-05-01T10:15',
      );
      verify(() => onChanged.call('2024-05-01T10:15')).called(1);
    });

    testWidgets('disables picker when disabled is true', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.datetimeLocal,
              label: 'Appointment',
              disabled: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final button = tester.widget<material.IconButton>(
        find.byType(material.IconButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('selecting a date and time via the pickers invokes onChanged', (
      tester,
    ) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.datetimeLocal,
              label: 'Appointment',
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.tap(find.byIcon(material.Icons.event));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final captured =
          verify(() => onChanged.call(captureAny<dynamic>())).captured.single
              as String;
      expect(DateTime.tryParse(captured), isNotNull);
    });
  });

  group('FormFieldBuilder file field', () {
    late FilePickerPlatform originalPlatform;

    setUp(() {
      originalPlatform = FilePickerPlatform.instance;
    });

    tearDown(() {
      FilePickerPlatform.instance = originalPlatform;
    });

    testWidgets('renders Choose File button by default', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.file,
              label: 'Attachment',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Choose File'), findsOneWidget);
      expect(find.byIcon(material.Icons.upload_file), findsOneWidget);
    });

    testWidgets('renders Choose Files button for fileMultiple', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.fileMultiple,
              label: 'Attachments',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Choose Files'), findsOneWidget);
    });

    testWidgets('shows current single-file value', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.file,
              label: 'Attachment',
            ),
            value: 'resume.pdf',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('resume.pdf'), findsOneWidget);
    });

    testWidgets('shows current list of file names', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.fileMultiple,
              label: 'Attachments',
            ),
            value: const ['a.png', 'b.png'],
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('a.png'), findsOneWidget);
      expect(find.text('b.png'), findsOneWidget);
    });

    testWidgets('does not call onChanged when pickFile returns null', (
      tester,
    ) async {
      final fake = _FakeFilePickerPlatform(singleResult: null);
      FilePickerPlatform.instance = fake;
      final onChanged = _MockValueChanged();

      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.file,
              label: 'Attachment',
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.tap(find.text('Choose File'));
      await tester.pumpAndSettle();

      expect(fake.pickFileCalled, isTrue);
      verifyNever(() => onChanged.call(any<dynamic>()));
    });

    testWidgets('does not call onChanged when pickFiles returns empty', (
      tester,
    ) async {
      final fake = _FakeFilePickerPlatform(multiResult: const []);
      FilePickerPlatform.instance = fake;
      final onChanged = _MockValueChanged();

      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.fileMultiple,
              label: 'Attachments',
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.tap(find.text('Choose Files'));
      await tester.pumpAndSettle();

      expect(fake.pickFilesCalled, isTrue);
      verifyNever(() => onChanged.call(any<dynamic>()));
    });

    testWidgets('requests FileType.custom with extensions when accept set', (
      tester,
    ) async {
      final fake = _FakeFilePickerPlatform(singleResult: null);
      FilePickerPlatform.instance = fake;

      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.file,
              label: 'Attachment',
              accept: '.png, .jpg ,gif',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('Choose File'));
      await tester.pumpAndSettle();

      expect(fake.capturedType, FileType.custom);
      expect(fake.capturedExtensions, ['png', 'jpg', 'gif']);
    });

    testWidgets('requests FileType.any when accept not set', (tester) async {
      final fake = _FakeFilePickerPlatform(multiResult: const []);
      FilePickerPlatform.instance = fake;

      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.fileMultiple,
              label: 'Attachments',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('Choose Files'));
      await tester.pumpAndSettle();

      expect(fake.capturedType, FileType.any);
      expect(fake.capturedExtensions, isNull);
    });

    testWidgets('calls onChanged with file name when pickFile returns a file', (
      tester,
    ) async {
      final fake = _FakeFilePickerPlatform(
        singleResult: _FakePlatformFile('resume.pdf'),
      );
      FilePickerPlatform.instance = fake;
      final onChanged = _MockValueChanged();

      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.file,
              label: 'Attachment',
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.tap(find.text('Choose File'));
      await tester.pumpAndSettle();

      verify(() => onChanged.call('resume.pdf')).called(1);
    });

    testWidgets(
      'calls onChanged with file names when pickFiles returns files',
      (tester) async {
        final fake = _FakeFilePickerPlatform(
          multiResult: [_FakePlatformFile('a.png'), _FakePlatformFile('b.png')],
        );
        FilePickerPlatform.instance = fake;
        final onChanged = _MockValueChanged();

        await tester.pumpWidget(
          _wrap(
            FormFieldBuilder(
              field: const FormFieldConfig(
                name: 'f',
                type: FormFieldType.fileMultiple,
                label: 'Attachments',
              ),
              value: null,
              onChanged: onChanged.call,
            ),
          ),
        );

        await tester.tap(find.text('Choose Files'));
        await tester.pumpAndSettle();

        verify(() => onChanged.call(['a.png', 'b.png'])).called(1);
      },
    );

    testWidgets('disables button when disabled is true', (tester) async {
      final fake = _FakeFilePickerPlatform();
      FilePickerPlatform.instance = fake;

      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.file,
              label: 'Attachment',
              disabled: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final button = tester.widget<material.OutlinedButton>(
        find.byType(material.OutlinedButton),
      );
      expect(button.onPressed, isNull);

      await tester.tap(find.text('Choose File'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(fake.pickFileCalled, isFalse);
    });
  });

  group('FormFieldBuilder checkbox label position', () {
    testWidgets('does not render shared label row for checkbox', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.checkbox,
              label: 'Accept terms',
            ),
            value: false,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Accept terms'), findsOneWidget);
      expect(find.byType(material.Checkbox), findsOneWidget);
    });
  });

  group('FormFieldBuilder additional coverage', () {
    testWidgets('text field with min/max/pattern attributes present', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.text,
              label: 'Username',
              min: 3,
              max: 20,
              pattern: r'^[a-zA-Z0-9_]+$',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(material.TextFormField), findsOneWidget);
    });

    testWidgets('dropdown with null value selects defaultValue', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.select,
              label: 'Status',
              options: [
                FormFieldOption(value: 'active', label: 'Active'),
                FormFieldOption(value: 'inactive', label: 'Inactive'),
              ],
              defaultValue: 'active',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final dropdown = tester.widget<material.DropdownButtonFormField<dynamic>>(
        find.byType(material.DropdownButtonFormField<dynamic>),
      );
      expect(dropdown.initialValue, 'active');
    });

    testWidgets('file field with accept filter parsed correctly', (
      tester,
    ) async {
      final fake = _FakeFilePickerPlatform(singleResult: null);
      FilePickerPlatform.instance = fake;

      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.file,
              label: 'Document',
              accept: '.pdf, .doc',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      await tester.tap(find.text('Choose File'));
      await tester.pumpAndSettle();

      expect(fake.capturedExtensions, ['pdf', 'doc']);
    });

    testWidgets('multiline field with value renders content', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.multiline,
              label: 'Items',
            ),
            value: const ['apple', 'banana'],
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(material.TextFormField), findsOneWidget);
    });

    testWidgets('checkbox-multi with null value renders unchecked', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.checkboxMulti,
              label: 'Permissions',
              options: [
                FormFieldOption(value: 'read', label: 'Read'),
                FormFieldOption(value: 'write', label: 'Write'),
              ],
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      final tiles = tester
          .widgetList<material.CheckboxListTile>(
            find.byType(material.CheckboxListTile),
          )
          .toList();
      expect(tiles.every((t) => t.value == false), isTrue);
    });

    testWidgets('radio group with no initial value renders', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.radio,
              label: 'Priority',
              options: [
                FormFieldOption(value: 'high', label: 'High'),
                FormFieldOption(value: 'low', label: 'Low'),
              ],
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byType(material.RadioListTile<dynamic>), findsWidgets);
    });

    testWidgets('number field strips non-numeric from mixed input', (
      tester,
    ) async {
      final onChanged = _MockValueChanged();
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.number,
              label: 'Count',
            ),
            value: null,
            onChanged: onChanged.call,
          ),
        ),
      );

      await tester.enterText(find.byType(material.TextFormField), 'x1y2z3');
      verify(() => onChanged.call('123')).called(1);
    });

    testWidgets('required field with description and help text shows all', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          FormFieldBuilder(
            field: const FormFieldConfig(
              name: 'f',
              type: FormFieldType.text,
              label: 'Email',
              required: true,
              description: 'Your work email',
              helpText: 'e.g. user@company.com',
            ),
            value: null,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text(' *'), findsOneWidget);
      expect(find.text('Your work email'), findsOneWidget);
      expect(find.text('e.g. user@company.com'), findsOneWidget);
    });
  });
}
