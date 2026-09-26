import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_ui/penguin_ui.dart';
import 'package:penguincloud/features/springboard/domain/springboard_item.dart';
import 'package:penguincloud/features/springboard/presentation/springboard_tile.dart';

void main() {
  const testItem = SpringboardItem(
    id: 'dashboard',
    title: 'Dashboard',
    icon: SpringboardIcon.dashboard,
    route: '/dashboard',
    description: 'System overview',
  );

  Widget buildTestWidget({VoidCallback? onTap, SpringboardItem? item}) {
    return MaterialApp(
      theme: PenguinTheme.dark(),
      home: Scaffold(
        body: SpringboardTile(item: item ?? testItem, onTap: onTap ?? () {}),
      ),
    );
  }

  group('SpringboardTile', () {
    testWidgets('renders title and description', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('System overview'), findsOneWidget);
    });

    testWidgets('renders the mapped Material icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byIcon(Icons.dashboard), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildTestWidget(onTap: () => tapped = true));

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('renders without a description', (tester) async {
      const noDescItem = SpringboardItem(
        id: 'settings',
        title: 'Settings',
        icon: SpringboardIcon.settings,
        route: '/settings',
      );

      await tester.pumpWidget(buildTestWidget(item: noDescItem));

      expect(find.text('Settings'), findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);
    });
  });

  group('materialIconFor', () {
    test('maps every SpringboardIcon to a distinct Material icon', () {
      final mapped = SpringboardIcon.values.map(materialIconFor).toSet();
      expect(mapped, hasLength(SpringboardIcon.values.length));
    });
  });
}
