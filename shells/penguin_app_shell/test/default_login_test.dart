import 'package:flutter/material.dart';
import 'package:flutter_libs/flutter_libs.dart'
    show LoginPageBuilder, LoginResponse;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_testing/penguin_testing.dart';
import 'package:penguin_ui/penguin_ui.dart' show AppBrand;

/// In-memory [SessionStore] stand-in — the real default touches
/// `flutter_secure_storage`, which has no working platform implementation
/// under `flutter_test`.
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

AppConfig _config() => AppConfig(
  productKey: 'product',
  appVersion: '1.0.0',
  environment: PenguinEnvironment.prealpha,
  apiBaseUrl: Uri.parse('https://api.product.example'),
  licenseServerUrl: 'https://license.penguintech.io',
);

Session _session() => Session(
  accessToken: 'fake-token',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  claims: JwtClaims.fromJson(const {}),
);

AppManifest _manifest({
  AuthConfig? auth,
  Widget Function(BuildContext, WidgetRef)? loginBuilder,
  AppBrand brand = const AppBrand(),
}) => AppManifest(
  productKey: 'product',
  appName: 'Test App',
  appVersion: '1.0.0',
  config: _config(),
  auth:
      auth ??
      AuthConfig.hosted(
        issuer: Uri.parse('https://api.product.example'),
        clientId: 'test',
        redirectUri: 'io.penguintech.test://oauth/callback',
      ),
  features: const [],
  loginBuilder: loginBuilder,
  brand: brand,
);

Future<void> _pump(
  WidgetTester tester,
  AppManifest manifest, {
  required FakeAuthBackend authBackend,
}) async {
  final overrides = <Override>[
    authBackendProvider.overrideWithValue(authBackend),
    sessionStoreProvider.overrideWithValue(_FakeSessionStore()),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) =>
              buildLoginScreen(context, ref, manifest),
        ),
      ),
    ),
  );
}

void main() {
  group('HostedLoginScreen', () {
    testWidgets(
      'shows app name, logo, and a single Continue to sign in button',
      (tester) async {
        final manifest = _manifest();
        await _pump(
          tester,
          manifest,
          authBackend: FakeAuthBackend()..queueLogin(Result.ok(_session())),
        );

        expect(find.text('Test App'), findsOneWidget);
        expect(find.text('Continue to sign in'), findsOneWidget);
        // No credential fields are ever rendered (spec §4.5).
        expect(find.byType(TextField), findsNothing);
        expect(find.byType(TextFormField), findsNothing);
      },
    );

    testWidgets('renders a logo image when the brand specifies one', (
      tester,
    ) async {
      final manifest = _manifest(
        brand: const AppBrand(logoAsset: 'assets/logo.png'),
      );
      await _pump(
        tester,
        manifest,
        authBackend: FakeAuthBackend()..queueLogin(Result.ok(_session())),
      );
      // The asset isn't bundled in this test, so loading it errors — that's
      // expected and irrelevant to what's under test (that the brand's logo
      // is wired into an Image.asset at all).
      expect(find.byType(Image), findsOneWidget);
      tester.takeException();
    });

    testWidgets('tapping the button logs in via LoginRequest.interactive()', (
      tester,
    ) async {
      final authBackend = FakeAuthBackend()..queueLogin(Result.ok(_session()));
      await _pump(tester, _manifest(), authBackend: authBackend);

      await tester.tap(find.text('Continue to sign in'));
      await tester.pumpAndSettle();

      expect(authBackend.loginRequests, hasLength(1));
      expect(authBackend.loginRequests.single, isA<Interactive>());
    });

    testWidgets('a failed login shows an inline error with a retry action', (
      tester,
    ) async {
      final authBackend = FakeAuthBackend()
        ..queueLogin(
          const Result.err(AuthFailure(null, 'Login was cancelled')),
        );
      await _pump(tester, _manifest(), authBackend: authBackend);

      await tester.tap(find.text('Continue to sign in'));
      await tester.pumpAndSettle();

      expect(
        find.text('Authentication failed. Please sign in again.'),
        findsOneWidget,
      );
      expect(find.text('Retry sign in'), findsOneWidget);

      // Retry issues a second interactive login attempt.
      authBackend.queueLogin(Result.ok(_session()));
      await tester.tap(find.text('Retry sign in'));
      await tester.pumpAndSettle();
      expect(authBackend.loginRequests, hasLength(2));
    });
  });

  group('buildLoginScreen', () {
    testWidgets('a manifest loginBuilder override wins over every default', (
      tester,
    ) async {
      final manifest = _manifest(
        loginBuilder: (context, ref) => const Text('CUSTOM_LOGIN'),
      );
      await _pump(tester, manifest, authBackend: FakeAuthBackend());

      expect(find.text('CUSTOM_LOGIN'), findsOneWidget);
      expect(find.text('Continue to sign in'), findsNothing);
    });

    testWidgets(
      'AuthConfig.password renders the transitional LoginPageBuilder',
      (tester) async {
        final manifest = _manifest(auth: const AuthConfig.password());
        await _pump(tester, manifest, authBackend: FakeAuthBackend());

        // LoginPageBuilder renders credential fields; HostedLoginScreen never
        // does — presence of any text field confirms the password path was
        // used instead of the hosted default.
        expect(find.text('Continue to sign in'), findsNothing);
        expect(find.byType(TextFormField), findsWidgets);
      },
    );

    testWidgets(
      'a successful password-form login completes AuthController.login',
      (tester) async {
        final manifest = _manifest(auth: const AuthConfig.password());
        final authBackend = FakeAuthBackend()
          ..queueLogin(Result.ok(_session()));
        await _pump(tester, manifest, authBackend: authBackend);

        // Drive the transitional path's onLoginSuccess directly rather than
        // filling in and submitting the real form — LoginPageBuilder's own
        // submission flow is flutter_libs' concern, not this shell's.
        final builder = tester.widget<LoginPageBuilder>(
          find.byType(LoginPageBuilder),
        );
        builder.onLoginSuccess!(
          const LoginResponse(
            success: true,
            token: 'abc.def.ghi',
            refreshToken: 'r1',
          ),
        );
        await tester.pump();

        expect(authBackend.loginRequests, hasLength(1));
        expect(authBackend.loginRequests.single, isA<FromLoginResponse>());
      },
    );
  });
}
