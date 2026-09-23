import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_ui/penguin_ui.dart';

void main() {
  group('FormFactor', () {
    testWidgets('of returns phone for widths < 600', (tester) async {
      late FormFactor result;

      tester.view.physicalSize = const Size(599, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                result = FormFactor.of(context);
                return Container();
              },
            ),
          ),
        ),
      );

      expect(result, FormFactor.phone);
    });

    testWidgets('of returns tablet for widths 600-899', (tester) async {
      late FormFactor result;

      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                result = FormFactor.of(context);
                return Container();
              },
            ),
          ),
        ),
      );

      expect(result, FormFactor.tablet);
    });

    testWidgets('of returns tablet for width 899', (tester) async {
      late FormFactor result;

      tester.view.physicalSize = const Size(899, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                result = FormFactor.of(context);
                return Container();
              },
            ),
          ),
        ),
      );

      expect(result, FormFactor.tablet);
    });

    testWidgets('of returns expanded for widths >= 900', (tester) async {
      late FormFactor result;

      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                result = FormFactor.of(context);
                return Container();
              },
            ),
          ),
        ),
      );

      expect(result, FormFactor.expanded);
    });
  });
}
