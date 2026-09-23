import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_testing/penguin_testing.dart';

const _subjectKey = Key('golden-subject');

Widget _subject() {
  return const MaterialApp(
    home: ColoredBox(
      key: _subjectKey,
      color: Color(0xFF224466),
      child: SizedBox.expand(),
    ),
  );
}

void main() {
  group('penguinGolden', () {
    testWidgets('captures the located widget at the requested size', (
      tester,
    ) async {
      await tester.pumpWidget(_subject());

      await penguinGolden(
        tester,
        find.byKey(_subjectKey),
        'sample_colored_box',
        size: const Size(200, 100),
      );
    });

    testWidgets('resizes the test surface to the requested logical size', (
      tester,
    ) async {
      await tester.pumpWidget(_subject());

      const requested = Size(200, 100);
      await penguinGolden(
        tester,
        find.byKey(_subjectKey),
        'sample_colored_box',
        size: requested,
      );

      expect(
        tester.view.physicalSize,
        requested * tester.view.devicePixelRatio,
      );
    });
  });
}
