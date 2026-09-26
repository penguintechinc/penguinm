import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';
import 'package:mocktail/mocktail.dart';

class _MockVoidCallback extends Mock {
  void call();
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('FormBuilderModal', () {
    testWidgets('renders title and child content', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FormBuilderModal(
            title: 'Edit Profile',
            child: Text('form content'),
          ),
        ),
      );

      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('form content'), findsOneWidget);
    });

    testWidgets('uses default submit and cancel labels', (tester) async {
      await tester.pumpWidget(
        _wrap(const FormBuilderModal(title: 'T', child: SizedBox())),
      );

      expect(find.text('Submit'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('uses custom submit and cancel labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const FormBuilderModal(
            title: 'T',
            submitLabel: 'Send',
            cancelLabel: 'Dismiss',
            child: SizedBox(),
          ),
        ),
      );

      expect(find.text('Send'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
    });

    testWidgets('tapping submit invokes onSubmit', (tester) async {
      final onSubmit = _MockVoidCallback();
      await tester.pumpWidget(
        _wrap(
          FormBuilderModal(
            title: 'T',
            onSubmit: onSubmit.call,
            child: const SizedBox(),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Submit'));
      await tester.pump();

      verify(onSubmit.call).called(1);
    });

    testWidgets('tapping cancel invokes onCancel', (tester) async {
      final onCancel = _MockVoidCallback();
      await tester.pumpWidget(
        _wrap(
          FormBuilderModal(
            title: 'T',
            onCancel: onCancel.call,
            child: const SizedBox(),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pump();

      verify(onCancel.call).called(1);
    });

    testWidgets(
      'isSubmitting disables both buttons and shows a progress indicator',
      (tester) async {
        final onSubmit = _MockVoidCallback();
        final onCancel = _MockVoidCallback();
        await tester.pumpWidget(
          _wrap(
            FormBuilderModal(
              title: 'T',
              isSubmitting: true,
              onSubmit: onSubmit.call,
              onCancel: onCancel.call,
              child: const SizedBox(),
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Submit'), findsNothing);

        final submitButton = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        final cancelButton = tester.widget<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        expect(submitButton.onPressed, isNull);
        expect(cancelButton.onPressed, isNull);

        await tester.tap(find.byType(ElevatedButton));
        await tester.tap(find.byType(OutlinedButton));
        await tester.pump();

        verifyNever(onSubmit.call);
        verifyNever(onCancel.call);
      },
    );

    testWidgets('applies the configured maxWidth to the dialog content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const FormBuilderModal(title: 'T', maxWidth: 320, child: SizedBox()),
        ),
      );

      final constrainedBox = tester.widget<ConstrainedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is ConstrainedBox && widget.constraints.maxWidth == 320,
        ),
      );
      expect(constrainedBox.constraints.maxWidth, 320);
    });

    group('show', () {
      testWidgets('displays the modal as a dialog', (tester) async {
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => FormBuilderModal.show<void>(
                  context: context,
                  title: 'Dialog Title',
                  child: const Text('dialog body'),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byType(FormBuilderModal), findsOneWidget);
        expect(find.text('Dialog Title'), findsOneWidget);
        expect(find.text('dialog body'), findsOneWidget);
      });

      testWidgets('defaults onCancel to popping the route', (tester) async {
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => FormBuilderModal.show<void>(
                  context: context,
                  title: 'Dialog Title',
                  child: const SizedBox(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.byType(FormBuilderModal), findsOneWidget);

        await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(find.byType(FormBuilderModal), findsNothing);
      });

      testWidgets('an explicit onCancel overrides the default pop', (
        tester,
      ) async {
        final onCancel = _MockVoidCallback();
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => FormBuilderModal.show<void>(
                  context: context,
                  title: 'Dialog Title',
                  onCancel: onCancel.call,
                  child: const SizedBox(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
        await tester.pump();

        verify(onCancel.call).called(1);
        expect(find.byType(FormBuilderModal), findsOneWidget);
      });

      testWidgets('the dialog barrier is not dismissible', (tester) async {
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => FormBuilderModal.show<void>(
                  context: context,
                  title: 'Dialog Title',
                  child: const SizedBox(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();

        expect(find.byType(FormBuilderModal), findsOneWidget);
      });
    });
  });
}
