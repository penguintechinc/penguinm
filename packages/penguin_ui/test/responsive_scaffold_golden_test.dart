import 'package:flutter/material.dart';
import 'package:flutter_libs/flutter_libs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_ui/penguin_ui.dart';

void main() {
  group('ResponsiveScaffold goldens', () {
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
      const NavigationDestinationSpec(
        route: '/profile',
        label: 'Profile',
        icon: Icons.person_outlined,
        selectedIcon: Icons.person,
      ),
    ];

    testWidgets('phone form factor golden', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: PenguinTheme.dark(),
          home: ResponsiveScaffold(
            destinations: destinations,
            selectedIndex: 0,
            onSelect: (_) {},
            body: const Center(child: Text('Phone Body')),
          ),
        ),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(SidebarMenu), findsNothing);

      await expectLater(
        find.byType(ResponsiveScaffold),
        matchesGoldenFile('goldens/responsive_scaffold_phone.png'),
      );
    });

    testWidgets('tablet form factor golden', (tester) async {
      tester.view.physicalSize = const Size(834 * 3, 1194 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: PenguinTheme.dark(),
          home: ResponsiveScaffold(
            destinations: destinations,
            selectedIndex: 0,
            onSelect: (_) {},
            body: const Center(child: Text('Tablet Body')),
          ),
        ),
      );

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(SidebarMenu), findsNothing);

      await expectLater(
        find.byType(ResponsiveScaffold),
        matchesGoldenFile('goldens/responsive_scaffold_tablet.png'),
      );
    });

    testWidgets('expanded form factor golden', (tester) async {
      tester.view.physicalSize = const Size(1280 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: PenguinTheme.dark(),
          home: ResponsiveScaffold(
            destinations: destinations,
            selectedIndex: 0,
            onSelect: (_) {},
            body: const Center(child: Text('Expanded Body')),
            // Fixed width so the detail pane's Center doesn't shrink-wrap
            // flush against the Row's trailing edge — a bare Center here
            // reports the text's exact width with zero margin, which puts
            // the label's right edge at the screen boundary in the golden.
            detail: const SizedBox(
              width: 320,
              child: Center(child: Text('Detail Pane')),
            ),
          ),
        ),
      );

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.byType(SidebarMenu), findsOneWidget);
      expect(find.text('Detail Pane'), findsOneWidget);

      await expectLater(
        find.byType(ResponsiveScaffold),
        matchesGoldenFile('goldens/responsive_scaffold_expanded.png'),
      );
    });
  });
}
