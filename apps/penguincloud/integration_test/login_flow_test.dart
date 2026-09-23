import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/penguin_flags.dart';
import 'package:penguin_testing/penguin_testing.dart';
import 'package:penguincloud/manifest.dart';

AppConfig _testConfig() => AppConfig(
  productKey: 'penguincloud',
  appVersion: appVersion,
  environment: PenguinEnvironment.prealpha,
  apiBaseUrl: Uri.parse('https://api.penguincloud.example'),
  licenseServerUrl: 'https://license.penguintech.io',
);

/// Both module flags PenguinCloud gates its routes behind (spec §11.2),
/// pre-seeded via the injected [FlagCache] (`services:`) so navigation
/// past login doesn't depend on a reachable PostHog/license server —
/// required per this task's CRITICAL SHELL INTERFACE contract: real
/// `connectivity_plus`/`SharedPreferences`-backed collaborators hang under
/// `flutter_test`, so every collaborator here is injected via
/// [ShellServices], never the real one `Bootstrap.run` would otherwise
/// construct.
CachedFlags _enabledFlags() => CachedFlags(
  flags: const <String, Object?>{
    'penguincloud.springboard': true,
    'penguincloud.profile': true,
  },
  tier: 'free',
  lastFetched: DateTime.now(),
);

void main() {
  // No `IntegrationTestWidgetsFlutterBinding` here: this app's pubspec.yaml
  // (T1a-owned) does not declare `integration_test` as a dependency — the
  // same gap as the shared app template (`templates/penguin_app/__brick__`)
  // and `apps/penguin_reference/integration_test/app_test.dart`, both of
  // which run via plain `flutter_test` for the same reason (see
  // `docs/MIGRATION.md`). `flutter_test`'s own default binding is
  // sufficient for everything this file exercises.
  group('Login Flow', () {
    testWidgets('shows the login form when not authenticated, and reaches the '
        'springboard home after a successful password login', (tester) async {
      final authBackend = FakeAuthBackend()
        ..queueLogin(
          Result.ok(
            Session(
              accessToken: 'fake-token',
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
              claims: JwtClaims.fromJson(const <String, Object?>{
                'roles': <String>[],
              }),
            ),
          ),
        );
      final manifest = buildManifestFor(config: _testConfig());

      await runPenguinApp(
        manifest,
        services: ShellServices(
          connectivityMonitor: FakeConnectivityMonitor(),
          authBackend: authBackend,
          telemetryExporter: InMemoryTelemetryExporter(),
          flagCache: InMemoryFlagCache(initial: _enabledFlags()),
        ),
      );
      await tester.pumpAndSettle();

      // Unauthenticated at startup → the transitional password-login
      // form is shown, never the springboard.
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Your springboard'), findsNothing);

      // Complete login through the same AuthController the LoginPageBuilder
      // form itself would call on submit.
      final container = ProviderScope.containerOf(
        tester.element(find.text('Email')),
        listen: false,
      );
      await container
          .read(authControllerProvider.notifier)
          .login(
            const LoginRequest.password(
              email: 'penny@example.com',
              password: 'hunter2',
            ),
          );
      await tester.pumpAndSettle();

      expect(find.text('Your springboard'), findsOneWidget);
      expect(find.text('Email'), findsNothing);
    });
  });
}
