import 'package:flutter/material.dart';
import 'package:flutter_libs/flutter_libs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_ui/penguin_ui.dart';

void main() {
  group('ResponsiveScaffold', () {
    final destinations = [
      const NavigationDestinationSpec(
        route: '/home',
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
      ),
      const NavigationDestinationSpec(
        route: '/search',
        label: 'Search',
        icon: Icons.search_outlined,
        selectedIcon: Icons.search,
      ),
    ];

    testWidgets('phone form factor renders NavigationBar', (tester) async {
      tester.view.physicalSize = const Size(599, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var selectedIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return ResponsiveScaffold(
                destinations: destinations,
                selectedIndex: selectedIndex,
                onSelect: (index) {
                  setState(() => selectedIndex = index);
                },
                body: const Text('Body'),
              );
            },
          ),
        ),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(SidebarMenu), findsNothing);
    });

    testWidgets('phone form factor onSelect is called on navigation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(599, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var selectedIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return ResponsiveScaffold(
                destinations: destinations,
                selectedIndex: selectedIndex,
                onSelect: (index) {
                  setState(() => selectedIndex = index);
                },
                body: Text('Body $selectedIndex'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('Body 1'), findsOneWidget);
    });

    testWidgets('tablet form factor renders NavigationRail', (tester) async {
      tester.view.physicalSize = const Size(700, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var selectedIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return ResponsiveScaffold(
                destinations: destinations,
                selectedIndex: selectedIndex,
                onSelect: (index) {
                  setState(() => selectedIndex = index);
                },
                body: const Text('Body'),
              );
            },
          ),
        ),
      );

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(SidebarMenu), findsNothing);
    });

    testWidgets('tablet form factor onSelect is called on navigation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(700, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var selectedIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return ResponsiveScaffold(
                destinations: destinations,
                selectedIndex: selectedIndex,
                onSelect: (index) {
                  setState(() => selectedIndex = index);
                },
                body: Text('Body $selectedIndex'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('Body 1'), findsOneWidget);
    });

    testWidgets('expanded form factor renders SidebarMenu', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var selectedIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return ResponsiveScaffold(
                destinations: destinations,
                selectedIndex: selectedIndex,
                onSelect: (index) {
                  setState(() => selectedIndex = index);
                },
                body: const Text('Body'),
              );
            },
          ),
        ),
      );

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(SidebarMenu), findsOneWidget);
    });

    testWidgets('expanded form factor onSelect is called on navigation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var selectedIndex = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return ResponsiveScaffold(
                destinations: destinations,
                selectedIndex: selectedIndex,
                onSelect: (index) {
                  setState(() => selectedIndex = index);
                },
                body: Text('Body $selectedIndex'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('Body 1'), findsOneWidget);
    });

    testWidgets('expanded form factor renders detail pane when provided', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveScaffold(
            destinations: destinations,
            selectedIndex: 0,
            onSelect: (_) {},
            body: const Text('Body'),
            detail: const Text('Detail'),
          ),
        ),
      );

      expect(find.text('Detail'), findsOneWidget);
    });
  });
}
