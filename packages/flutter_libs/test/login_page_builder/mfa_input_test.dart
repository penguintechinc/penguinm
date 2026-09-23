import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('MFAInput', () {
    testWidgets('renders the configured number of digit boxes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MFAInput(length: 6, onCompleted: (_) {})),
        ),
      );

      expect(find.byType(TextField), findsNWidgets(6));
    });

    testWidgets(
      'auto-advances focus and calls onCompleted when all digits entered',
      (tester) async {
        String? completedCode;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MFAInput(
                length: 4,
                autoFocus: false,
                onCompleted: (code) => completedCode = code,
              ),
            ),
          ),
        );

        final fields = find.byType(TextField);
        for (var i = 0; i < 4; i++) {
          await tester.enterText(fields.at(i), '$i');
          await tester.pump();
        }

        expect(completedCode, '0123');
      },
    );

    testWidgets('rejects a non-digit character typed into a box', (
      tester,
    ) async {
      // regression: L4 requires digit-only filtering on the *typed* path,
      // not just the paste path. FilteringTextInputFormatter.digitsOnly
      // applies to every EditableText value update (typed or pasted) before
      // onChanged ever sees it, so a non-digit keystroke must never reach
      // the controller or onChanged/onCompleted.
      String? changedCode;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MFAInput(
              length: 4,
              autoFocus: false,
              onChanged: (code) => changedCode = code,
              onCompleted: (_) {},
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'a');
      await tester.pump();

      final firstField = tester.widget<TextField>(find.byType(TextField).first);
      expect(firstField.controller!.text, isEmpty);
      expect(changedCode, isNull);
    });

    testWidgets('pasting a full code fills every box', (tester) async {
      String? completedCode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MFAInput(
              length: 6,
              autoFocus: false,
              onCompleted: (code) => completedCode = code,
            ),
          ),
        ),
      );

      // Simulate pasting "123456" into the first box.
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pump();

      expect(completedCode, '123456');
    });

    testWidgets('pasting mixed alphanumeric content keeps only the digits', (
      tester,
    ) async {
      String? completedCode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MFAInput(
              length: 4,
              autoFocus: false,
              onCompleted: (code) => completedCode = code,
            ),
          ),
        ),
      );

      // Simulate pasting "1a2b3c4d" — digits-only filtering (formatter and
      // _handlePaste's own defensive regex) must reduce this to "1234".
      await tester.enterText(find.byType(TextField).first, '1a2b3c4d');
      await tester.pump();

      expect(completedCode, '1234');
    });

    testWidgets('pasting fewer digits than length focuses the next box', (
      tester,
    ) async {
      String? changedCode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MFAInput(
              length: 6,
              autoFocus: false,
              onChanged: (code) => changedCode = code,
              onCompleted: (_) {},
            ),
          ),
        ),
      );

      // Pasting fewer digits than the box count takes the
      // `digits.length < widget.length` branch, focusing box index 2 next.
      await tester.enterText(find.byType(TextField).first, '12');
      await tester.pump();

      expect(changedCode, '12');
      final thirdField = tester.widget<TextField>(find.byType(TextField).at(2));
      expect(thirdField.focusNode!.hasFocus, isTrue);
    });

    testWidgets(
      'backspace on an empty box clears and focuses the previous box',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MFAInput(length: 4, autoFocus: false, onCompleted: (_) {}),
            ),
          ),
        );

        final fields = find.byType(TextField);

        // Fill box 0, which auto-advances focus to box 1 (still empty).
        await tester.enterText(fields.at(0), '5');
        await tester.pump();
        expect(
          tester.widget<TextField>(fields.at(1)).focusNode!.hasFocus,
          isTrue,
        );

        // Backspace while box 1 is empty must clear box 0 and move focus
        // back to it — the KeyboardListener wrapping each box handles this
        // since the underlying TextField never sees a backspace on empty
        // text as a change event.
        await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
        await tester.pump();

        expect(
          tester.widget<TextField>(fields.at(0)).controller!.text,
          isEmpty,
        );
        expect(
          tester.widget<TextField>(fields.at(0)).focusNode!.hasFocus,
          isTrue,
        );
      },
    );
  });
}
