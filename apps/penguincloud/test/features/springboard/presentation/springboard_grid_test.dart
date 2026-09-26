import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_ui/penguin_ui.dart';
import 'package:penguincloud/features/springboard/presentation/springboard_grid.dart';

/// Test-only [AuthController] whose `build()` returns a fixed [AuthState]
/// directly, skipping the real login/session-store flow — the shortest
/// path to exercising a widget that reads `authControllerProvider` for
/// the current user's roles.
class _FixedAuthController extends AuthController {
  _FixedAuthController(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

Session _sessionWithRoles(List<String> roles) => Session(
  accessToken: 'fake-token',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  claims: JwtClaims.fromJson({'roles': roles}),
);

Widget _harness(AuthState authState) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(
        () => _FixedAuthController(authState),
      ),
    ],
    child: MaterialApp(
      theme: PenguinTheme.dark(),
      home: const Scaffold(body: SpringboardGrid()),
    ),
  );
}

void main() {
  group('SpringboardGrid role filtering', () {
    testWidgets('an unauthenticated viewer sees only the ungated items', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(const AuthState.unauthenticated()));
      await tester.pumpAndSettle();

      // Ungated: Dashboard, Teams. Gated (admin/maintainer): Users,
      // Settings, Monitoring, Logs — must not render.
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Teams'), findsOneWidget);
      expect(find.text('Users'), findsNothing);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Monitoring'), findsNothing);
      expect(find.text('Logs'), findsNothing);
    });

    testWidgets('a viewer role sees only the ungated items', (tester) async {
      await tester.pumpWidget(
        _harness(AuthState.authenticated(_sessionWithRoles(['viewer']))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Teams'), findsOneWidget);
      expect(find.text('Users'), findsNothing);
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets(
      'a maintainer role sees maintainer items but not admin-only ones',
      (tester) async {
        await tester.pumpWidget(
          _harness(AuthState.authenticated(_sessionWithRoles(['maintainer']))),
        );
        await tester.pumpAndSettle();

        expect(find.text('Settings'), findsOneWidget);
        expect(find.text('Monitoring'), findsOneWidget);
        expect(find.text('Logs'), findsOneWidget);
        expect(find.text('Users'), findsNothing);
      },
    );

    testWidgets('an admin role sees every springboard item', (tester) async {
      await tester.pumpWidget(
        _harness(AuthState.authenticated(_sessionWithRoles(['admin']))),
      );
      await tester.pumpAndSettle();

      for (final title in [
        'Dashboard',
        'Users',
        'Teams',
        'Settings',
        'Monitoring',
        'Logs',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
    });
  });

  testWidgets(
    'tapping a tile shows a "Navigate to <title>" SnackBar (legacy behaviour kept)',
    (tester) async {
      await tester.pumpWidget(
        _harness(AuthState.authenticated(_sessionWithRoles(['admin']))),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dashboard'));
      await tester.pump();

      expect(find.text('Navigate to Dashboard'), findsOneWidget);
    },
  );
}
