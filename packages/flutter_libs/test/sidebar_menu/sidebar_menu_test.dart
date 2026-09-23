import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('SidebarMenu', () {
    testWidgets('renders category headers and item labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarMenu(
              categories: const [
                MenuCategory(
                  header: 'Main',
                  items: [
                    MenuItem(
                      name: 'Dashboard',
                      href: '/dashboard',
                      icon: Icons.dashboard,
                    ),
                    MenuItem(name: 'Reports', href: '/reports'),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('MAIN'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      // Icon is only rendered for items that declare one.
      expect(find.byIcon(Icons.dashboard), findsOneWidget);
    });

    testWidgets('renders a headerless category without a header row', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarMenu(
              categories: const [
                MenuCategory(
                  header: null,
                  items: [MenuItem(name: 'Home', href: '/')],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets(
      'a non-collapsible category shows its header but no expand icon and '
      'always shows its items',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SidebarMenu(
                categories: const [
                  MenuCategory(
                    header: 'Pinned',
                    collapsible: false,
                    items: [MenuItem(name: 'Always Visible', href: '/a')],
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('PINNED'), findsOneWidget);
        expect(find.text('Always Visible'), findsOneWidget);
        expect(find.byIcon(Icons.expand_less), findsNothing);
        expect(find.byIcon(Icons.expand_more), findsNothing);
      },
    );

    testWidgets('a collapsible category collapses and re-expands on tap', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarMenu(
              categories: const [
                MenuCategory(
                  header: 'Toggleable',
                  items: [MenuItem(name: 'Nested Item', href: '/n')],
                ),
              ],
            ),
          ),
        ),
      );

      // Expanded by default.
      expect(find.text('Nested Item'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);

      await tester.tap(find.text('TOGGLEABLE'));
      await tester.pump();

      expect(find.text('Nested Item'), findsNothing);
      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      await tester.tap(find.text('TOGGLEABLE'));
      await tester.pump();

      expect(find.text('Nested Item'), findsOneWidget);
      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets(
      'a category whose items are all filtered out by role renders nothing',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SidebarMenu(
                userRole: 'viewer',
                categories: const [
                  MenuCategory(
                    header: 'Admin Only',
                    items: [
                      MenuItem(
                        name: 'Danger Zone',
                        href: '/danger',
                        roles: ['admin'],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('ADMIN ONLY'), findsNothing);
        expect(find.text('Danger Zone'), findsNothing);
      },
    );

    testWidgets(
      'role filtering hides items missing the required role and shows '
      'items with no role requirement or a matching role',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SidebarMenu(
                userRole: 'editor',
                categories: const [
                  MenuCategory(
                    header: 'Mixed',
                    items: [
                      MenuItem(name: 'Public', href: '/public'),
                      MenuItem(
                        name: 'Editor Only',
                        href: '/editor',
                        roles: ['editor'],
                      ),
                      MenuItem(
                        name: 'Admin Only',
                        href: '/admin',
                        roles: ['admin'],
                      ),
                      MenuItem(name: 'Empty Roles', href: '/empty', roles: []),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Public'), findsOneWidget);
        expect(find.text('Editor Only'), findsOneWidget);
        expect(find.text('Admin Only'), findsNothing);
        expect(find.text('Empty Roles'), findsOneWidget);
      },
    );

    testWidgets('a role-restricted item is hidden when userRole is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarMenu(
              categories: const [
                MenuCategory(
                  header: 'Restricted',
                  items: [
                    MenuItem(
                      name: 'Needs Role',
                      href: '/needs-role',
                      roles: ['admin'],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Needs Role'), findsNothing);
    });

    testWidgets('tapping an item invokes onItemTap with that item', (
      tester,
    ) async {
      MenuItem? tapped;
      const item = MenuItem(name: 'Click Me', href: '/click');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarMenu(
              categories: const [
                MenuCategory(header: null, items: [item]),
              ],
              onItemTap: (tappedItem) => tapped = tappedItem,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Click Me'));
      await tester.pump();

      expect(tapped, same(item));
    });

    testWidgets('tapping an item is a no-op when onItemTap is not set', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarMenu(
              categories: const [
                MenuCategory(
                  header: null,
                  items: [MenuItem(name: 'No Handler', href: '/none')],
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('No Handler'));
      await tester.pump();

      expect(find.text('No Handler'), findsOneWidget);
    });

    testWidgets(
      'activePath exact match and prefix match both mark the item active; '
      'a non-matching path does not',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SidebarMenu(
                activePath: '/reports/monthly',
                categories: const [
                  MenuCategory(
                    header: null,
                    items: [
                      MenuItem(name: 'Exact', href: '/reports/monthly'),
                      MenuItem(name: 'Prefix', href: '/reports'),
                      MenuItem(name: 'Unrelated', href: '/other'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );

        final exactText = tester.widget<Text>(find.text('Exact'));
        final unrelatedText = tester.widget<Text>(find.text('Unrelated'));

        expect(exactText.style!.fontWeight, FontWeight.w600);
        expect(unrelatedText.style!.fontWeight, FontWeight.normal);
      },
    );

    testWidgets('no activePath leaves every item inactive', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarMenu(
              categories: const [
                MenuCategory(
                  header: null,
                  items: [MenuItem(name: 'Idle', href: '/idle')],
                ),
              ],
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Idle'));
      expect(text.style!.fontWeight, FontWeight.normal);
    });

    testWidgets('renders a logo when provided and omits it when absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarMenu(categories: const [], logo: const Text('LOGO')),
          ),
        ),
      );

      expect(find.text('LOGO'), findsOneWidget);
    });

    testWidgets('omits the logo container when logo is null', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SidebarMenu(categories: const [])),
        ),
      );

      expect(find.text('LOGO'), findsNothing);
    });

    testWidgets('renders a sticky footer widget when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarMenu(
              categories: const [],
              footerWidget: const Text('FOOTER'),
            ),
          ),
        ),
      );

      expect(find.text('FOOTER'), findsOneWidget);
    });

    testWidgets('omits the footer container when footerWidget is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SidebarMenu(categories: const [])),
        ),
      );

      expect(find.text('FOOTER'), findsNothing);
    });

    testWidgets('applies a custom width and color config', (tester) async {
      const customColors = SidebarColorConfig(sidebarBackground: Colors.black);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SidebarMenu(
              categories: const [],
              width: 320,
              colorConfig: customColors,
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints!.maxWidth, 320);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.black);
    });
  });
}
