import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_testing/penguin_testing.dart';
import 'package:penguin_ui/penguin_ui.dart';
import 'package:penguincloud/features/profile/domain/user.dart';
import 'package:penguincloud/features/profile/presentation/profile_providers.dart';
import 'package:penguincloud/features/profile/presentation/profile_screen.dart';

/// In-memory [SessionStore] stand-in — the real default touches
/// `flutter_secure_storage`, which has no working platform implementation
/// under `flutter_test` (see `shells/penguin_app_shell/test/router_test.dart`
/// for the same pattern).
class _FakeSessionStore extends SessionStore {
  Session? _stored;

  @override
  Future<Session?> load() async => _stored;

  @override
  Future<void> save(Session session) async {
    _stored = session;
  }

  @override
  Future<void> clear() async {
    _stored = null;
  }
}

/// Test-only [AuthController] whose `build()` returns a fixed [AuthState]
/// directly — see the identical helper in `springboard_grid_test.dart`.
/// Only [logout] itself needs the real `AuthController` behaviour (calling
/// [authBackendProvider] when the current state is `Authenticated`), so
/// this only overrides `build()`.
class _FixedAuthController extends AuthController {
  _FixedAuthController(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

Session _session() => Session(
  accessToken: 'fake-token',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  claims: JwtClaims.fromJson(const {}),
);

const _user = User(
  id: 'user-1',
  email: 'penny@example.com',
  name: 'Penny Waddle',
  roles: ['admin', 'viewer'],
);

Widget _harness({
  required AsyncValue<Result<User>> profileState,
  FakeAuthBackend? authBackend,
}) {
  return ProviderScope(
    overrides: [
      profileProvider.overrideWith((ref) {
        return switch (profileState) {
          AsyncData(:final value) => Future.value(value),
          AsyncError(:final error) => Future<Result<User>>.error(error),
          _ => Completer<Result<User>>().future,
        };
      }),
      authBackendProvider.overrideWithValue(authBackend ?? FakeAuthBackend()),
      sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
      authControllerProvider.overrideWith(
        () => _FixedAuthController(AuthState.authenticated(_session())),
      ),
    ],
    // `Scaffold` mirrors the real ancestor `ProfileScreen` always renders
    // inside in production — `ResponsiveScaffold` (via `AppShellScaffold`,
    // spec §4.10) — which the sidebar's `ListTile`s need a `Material`
    // ancestor from.
    child: MaterialApp(
      theme: PenguinTheme.dark(),
      home: const Scaffold(body: ProfileScreen()),
    ),
  );
}

void main() {
  group('ProfileScreen', () {
    testWidgets('shows a loading indicator while the profile is fetching', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(profileState: const AsyncValue.loading()),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('renders profile details on success', (tester) async {
      await tester.pumpWidget(
        _harness(profileState: const AsyncValue.data(Result.ok(_user))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Penny Waddle'), findsWidgets);
      expect(find.text('penny@example.com'), findsWidgets);
      expect(find.text('admin, viewer'), findsOneWidget);
      expect(find.text('user-1'), findsOneWidget);
    });

    testWidgets('renders an ErrorView with retry on a Result.err', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          profileState: const AsyncValue.data(
            Result.err(ServerFailure(500, 'boom')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Server error. Please try again later.'), findsWidgets);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsWidgets);
    });

    testWidgets('renders an ErrorView when the future itself throws', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          profileState: AsyncValue.error(Exception('boom'), StackTrace.current),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FilledButton), findsWidgets);
    });

    testWidgets('the sign-out button logs the user out', (tester) async {
      final authBackend = FakeAuthBackend()
        ..queueLogout(const Result<void>.ok(null));

      await tester.pumpWidget(
        _harness(
          profileState: const AsyncValue.data(Result.ok(_user)),
          authBackend: authBackend,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Sign Out'));
      await tester.pumpAndSettle();

      expect(authBackend.loggedOutSessions, hasLength(1));
    });

    testWidgets('shows the tablet account sidebar at tablet width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _harness(profileState: const AsyncValue.data(Result.ok(_user))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('does not show the tablet sidebar at phone width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _harness(profileState: const AsyncValue.data(Result.ok(_user))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Security'), findsNothing);
    });
  });
}
