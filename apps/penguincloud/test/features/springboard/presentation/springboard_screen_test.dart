import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_ui/penguin_ui.dart';
import 'package:penguincloud/features/springboard/presentation/springboard_screen.dart';

/// Test-only [AuthController] whose `build()` returns a fixed [AuthState]
/// directly — see the identical helper in `springboard_grid_test.dart` for
/// why this is the shortest path to an authenticated widget test.
class _FixedAuthController extends AuthController {
  _FixedAuthController(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

Session _sessionWithClaims(Map<String, Object?> claims) => Session(
  accessToken: 'fake-token',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  claims: JwtClaims.fromJson(claims),
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
      home: const SpringboardScreen(),
    ),
  );
}

void main() {
  group('SpringboardScreen greeting', () {
    testWidgets('greets by the name claim when present', (tester) async {
      await tester.pumpWidget(
        _harness(
          AuthState.authenticated(_sessionWithClaims({'name': 'Penny Waddle'})),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome, Penny Waddle'), findsOneWidget);
    });

    testWidgets('falls back to the email claim when name is absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          AuthState.authenticated(
            _sessionWithClaims({'email': 'penny@example.com'}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome, penny@example.com'), findsOneWidget);
    });

    testWidgets('falls back to the subject id when name/email are absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(AuthState.authenticated(_sessionWithClaims({'sub': 'u-1'}))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Welcome, u-1'), findsOneWidget);
    });

    testWidgets('falls back to "User" when unauthenticated', (tester) async {
      await tester.pumpWidget(_harness(const AuthState.unauthenticated()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome, User'), findsOneWidget);
    });

    testWidgets('renders the springboard subtitle and grid', (tester) async {
      await tester.pumpWidget(
        _harness(AuthState.authenticated(_sessionWithClaims({}))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your springboard'), findsOneWidget);
      expect(find.text('Dashboard'), findsOneWidget);
    });
  });
}
