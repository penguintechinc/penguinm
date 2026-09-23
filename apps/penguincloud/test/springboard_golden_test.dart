import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_testing/penguin_testing.dart';
import 'package:penguin_ui/penguin_ui.dart';
import 'package:penguincloud/features/springboard/presentation/springboard_screen.dart';

/// Test-only [AuthController] whose `build()` returns a fixed [AuthState]
/// directly — see the identical helper in `springboard_grid_test.dart`.
class _FixedAuthController extends AuthController {
  _FixedAuthController(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

Session _adminSession() => Session(
  accessToken: 'fake-token',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  claims: JwtClaims.fromJson(const {
    'name': 'Penny Waddle',
    'roles': ['admin'],
  }),
);

Future<void> _pumpHome(WidgetTester tester, Size size) async {
  // Set the target viewport size *before* the first pump/layout (rather
  // than relying solely on `penguinGolden`'s own resize-then-settle) — a
  // widget laid out once at the default test-window size, then resized
  // for a text-wrapping-sensitive header, was observed to leave stale/
  // overlapping glyph rendering in the captured golden on this
  // environment's headless renderer.
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => _FixedAuthController(AuthState.authenticated(_adminSession())),
        ),
      ],
      // `Scaffold` mirrors the real ancestor `SpringboardScreen` always
      // renders inside in production (`ResponsiveScaffold`, spec §4.10) —
      // without it, header text painted directly under `SafeArea` (no
      // `Material` ancestor) rendered with corrupted glyphs in this
      // environment's headless golden renderer.
      child: MaterialApp(
        theme: PenguinTheme.dark(),
        home: const Scaffold(body: SpringboardScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await penguinGolden(
    tester,
    find.byType(SpringboardScreen),
    size == const Size(390, 844) ? 'springboard_phone' : 'springboard_tablet',
    size: size,
  );
}

void main() {
  group('SpringboardScreen goldens', () {
    testWidgets('phone (390x844)', (tester) async {
      await _pumpHome(tester, const Size(390, 844));
    });

    testWidgets('tablet (834x1194)', (tester) async {
      await _pumpHome(tester, const Size(834, 1194));
    });
  });
}
