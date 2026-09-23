import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

const _urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  setUpAll(() {
    registerFallbackValue('');
  });

  group('LoginPageBuilder', () {
    testWidgets('renders email, password fields and a sign-in button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
          ),
        ),
      );

      expect(find.text('Test App'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('shows validation errors when submitting empty fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
          ),
        ),
      );

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('shows an error message on a failed (401) login', (
      tester,
    ) async {
      final client = MockClient((request) async {
        return http.Response(
          json.encode({'success': false, 'error': 'Invalid credentials'}),
          401,
        );
      });

      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            httpClient: client,
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid credentials'), findsOneWidget);
    });

    testWidgets('shows the MFA modal when the server requests it', (
      tester,
    ) async {
      final client = MockClient((request) async {
        return http.Response(
          json.encode({'success': false, 'mfaRequired': true}),
          200,
        );
      });

      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            mfaConfig: const MFAConfig(enabled: true),
            httpClient: client,
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Two-Factor Authentication'), findsOneWidget);
    });

    testWidgets(
      'shows a distinct error for a 500 server error without triggering CAPTCHA logic',
      (tester) async {
        final client = MockClient((request) async {
          return http.Response('Internal Server Error', 500);
        });

        await tester.pumpWidget(
          _wrap(
            LoginPageBuilder(
              apiConfig: LoginApiConfig(
                loginUrl: 'https://api.example.com/login',
              ),
              branding: const BrandingConfig(appName: 'Test App'),
              captchaConfig: const CaptchaConfig(
                enabled: true,
                failedAttemptsThreshold: 1,
                challengeUrl: 'https://api.example.com/altcha',
              ),
              httpClient: client,
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'user@example.com',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'password123');
        await tester.tap(find.text('Sign In'));
        await tester.pumpAndSettle();

        expect(
          find.text('Server error. Please try again later.'),
          findsOneWidget,
        );
        // A single 500 must not have tripped the CAPTCHA threshold of 1.
        expect(find.byType(CaptchaWidget), findsNothing);
      },
    );

    testWidgets('calls onLoginSuccess on a successful login', (tester) async {
      LoginResponse? successResponse;
      final client = MockClient((request) async {
        return http.Response(
          json.encode({
            'success': true,
            'token': 'access-token',
            'user': {'id': '1', 'email': 'user@example.com'},
          }),
          200,
        );
      });

      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            httpClient: client,
            onLoginSuccess: (response) => successResponse = response,
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(successResponse, isNotNull);
      expect(successResponse!.success, isTrue);
    });

    testWidgets('persists tokens via tokenStorage on a successful login', (
      tester,
    ) async {
      final mockStorage = _MockFlutterSecureStorage();
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});
      final tokenStorage = TokenStorage(storage: mockStorage);

      final client = MockClient((request) async {
        return http.Response(
          json.encode({
            'success': true,
            'token': 'access-token',
            'refreshToken': 'refresh-token',
            'user': {'id': '1', 'email': 'user@example.com'},
          }),
          200,
        );
      });

      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            httpClient: client,
            tokenStorage: tokenStorage,
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      verify(
        () => mockStorage.write(
          key: 'flutter_libs.auth.access_token',
          value: 'access-token',
        ),
      ).called(1);
      verify(
        () => mockStorage.write(
          key: 'flutter_libs.auth.refresh_token',
          value: 'refresh-token',
        ),
      ).called(1);

      // This widget has no logout UI of its own — verify the documented
      // caller-driven logout path (tokenStorage.clear()) actually clears
      // what was just persisted.
      await tokenStorage.clear();
      verify(
        () => mockStorage.delete(key: 'flutter_libs.auth.access_token'),
      ).called(1);
      verify(
        () => mockStorage.delete(key: 'flutter_libs.auth.refresh_token'),
      ).called(1);
    });

    testWidgets('does not touch tokenStorage on a failed login', (
      tester,
    ) async {
      final mockStorage = _MockFlutterSecureStorage();
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      final tokenStorage = TokenStorage(storage: mockStorage);

      final client = MockClient((request) async {
        return http.Response(
          json.encode({'success': false, 'error': 'Invalid credentials'}),
          401,
        );
      });

      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            httpClient: client,
            tokenStorage: tokenStorage,
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      verifyNever(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      );
    });

    testWidgets(
      'shows the CAPTCHA challenge once the failed-attempt threshold is '
      'reached, and blocks a further submit until it is verified',
      (tester) async {
        final client = MockClient((request) async {
          return http.Response(
            json.encode({'success': false, 'error': 'Invalid credentials'}),
            401,
          );
        });

        await tester.pumpWidget(
          _wrap(
            LoginPageBuilder(
              apiConfig: LoginApiConfig(
                loginUrl: 'https://api.example.com/login',
              ),
              branding: const BrandingConfig(appName: 'Test App'),
              captchaConfig: const CaptchaConfig(
                enabled: true,
                failedAttemptsThreshold: 1,
                challengeUrl: 'https://api.example.com/altcha',
              ),
              httpClient: client,
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'user@example.com',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'password123');
        await tester.tap(find.text('Sign In'));
        await tester.pumpAndSettle();

        // A single 401 trips the threshold of 1 — the CAPTCHA now shows.
        expect(find.byType(CaptchaWidget), findsOneWidget);

        // Submitting again without completing the CAPTCHA is blocked before
        // another request is attempted.
        await tester.tap(find.text('Sign In'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please complete the CAPTCHA verification'),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows an error for a malformed (non-JSON) response body', (
      tester,
    ) async {
      final client = MockClient((request) async {
        return http.Response('not json', 200);
      });

      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            httpClient: client,
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(
        find.text('Unexpected server response. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('sends the login request via PUT when configured', (
      tester,
    ) async {
      String? usedMethod;
      final client = MockClient((request) async {
        usedMethod = request.method;
        return http.Response(
          json.encode({'success': true, 'token': 'access-token'}),
          200,
        );
      });

      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
              method: LoginMethod.put,
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            httpClient: client,
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(usedMethod, 'PUT');
    });

    testWidgets('shows a timeout error when the request times out', (
      tester,
    ) async {
      final client = MockClient((request) async {
        throw TimeoutException('timed out');
      });

      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            httpClient: client,
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Request timed out. Please try again.'), findsOneWidget);
    });

    testWidgets('shows a generic connection error for other exceptions', (
      tester,
    ) async {
      final client = MockClient((request) async {
        throw Exception('socket boom');
      });

      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            httpClient: client,
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Connection error. Please try again.'), findsOneWidget);
    });

    testWidgets('applies transformErrorMessage to the displayed error', (
      tester,
    ) async {
      final client = MockClient((request) async {
        return http.Response(
          json.encode({'success': false, 'error': 'raw-error-code'}),
          401,
        );
      });

      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            httpClient: client,
            transformErrorMessage: (e) => 'Friendly: $e',
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Friendly: raw-error-code'), findsOneWidget);
    });

    testWidgets(
      'creates and closes its own http client when none is provided',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            LoginPageBuilder(
              apiConfig: LoginApiConfig(
                loginUrl: 'https://api.example.com/login',
              ),
              branding: const BrandingConfig(appName: 'Test App'),
            ),
          ),
        );

        await tester.enterText(
          find.byType(TextFormField).at(0),
          'user@example.com',
        );
        await tester.enterText(find.byType(TextFormField).at(1), 'password123');
        await tester.tap(find.text('Sign In'));
        await tester.pumpAndSettle();

        // flutter_test blocks real HTTP with a fake response once the test
        // binding is initialised — the widget must still create, use, and
        // close its own client without hanging, ending back on an enabled
        // "Sign In" button rather than stuck submitting.
        expect(tester.takeException(), isNull);
        expect(find.text('Sign In'), findsOneWidget);
      },
    );

    testWidgets('renders the branding logo instead of the app name when set', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(
              appName: 'Test App',
              logo: Icon(Icons.ac_unit, key: Key('logo-icon')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('logo-icon')), findsOneWidget);
      expect(find.text('Test App'), findsNothing);
    });

    testWidgets('renders the tagline when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(
              appName: 'Test App',
              tagline: 'Welcome back',
            ),
          ),
        ),
      );

      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('renders a custom footer instead of the default LoginFooter', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(
              appName: 'Test App',
              githubRepo: 'https://github.com/penguintechinc/penguinm',
            ),
            footer: const Text('Custom footer content'),
          ),
        ),
      );

      expect(find.text('Custom footer content'), findsOneWidget);
      expect(find.byType(LoginFooter), findsNothing);
    });

    testWidgets('renders social login buttons and reports taps via '
        'onSocialLoginInitiated and onLinkTap', (tester) async {
      SocialProvider? tappedProvider;
      String? initiatedState;
      String? tappedUrl;

      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            socialProviders: const [
              BuiltInOAuth2Provider(
                provider: BuiltInProviderType.google,
                clientId: 'client-1',
              ),
            ],
            onSocialLoginInitiated: (provider, state, codeVerifier) {
              tappedProvider = provider;
              initiatedState = state;
            },
            onLinkTap: (url) => tappedUrl = url,
          ),
        ),
      );

      expect(find.byType(OutlinedButton), findsOneWidget);

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(tappedProvider, isA<BuiltInOAuth2Provider>());
      expect(initiatedState, isNotNull);
      expect(tappedUrl, isNotNull);
    });

    testWidgets(
      'a social login without onLinkTap launches the URL externally',
      (tester) async {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_urlLauncherChannel, (call) async {
              calls.add(call);
              if (call.method == 'launch') return true;
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(_urlLauncherChannel, null);
        });

        await tester.pumpWidget(
          _wrap(
            LoginPageBuilder(
              apiConfig: LoginApiConfig(
                loginUrl: 'https://api.example.com/login',
              ),
              branding: const BrandingConfig(appName: 'Test App'),
              socialProviders: const [
                BuiltInOAuth2Provider(
                  provider: BuiltInProviderType.google,
                  clientId: 'client-1',
                ),
              ],
            ),
          ),
        );

        await tester.tap(find.byType(OutlinedButton));
        await tester.pumpAndSettle();

        expect(calls, hasLength(1));
        expect(calls.single.method, 'launch');
      },
    );

    testWidgets(
      'CustomOAuth2Provider and SAMLProvider social logins build a URL and '
      'route it through onLinkTap',
      (tester) async {
        final tappedUrls = <String>[];

        await tester.pumpWidget(
          _wrap(
            LoginPageBuilder(
              apiConfig: LoginApiConfig(
                loginUrl: 'https://api.example.com/login',
              ),
              branding: const BrandingConfig(appName: 'Test App'),
              socialProviders: const [
                CustomOAuth2Provider(
                  authUrl: 'https://idp.example.com/authorize',
                  clientId: 'client-y',
                  label: 'Acme SSO',
                ),
                SAMLProvider(
                  idpSsoUrl: 'https://idp.example.com/sso',
                  entityId: 'entity-1',
                  acsUrl: 'https://sp.example.com/acs',
                ),
              ],
              onLinkTap: (url) => tappedUrls.add(url),
            ),
          ),
        );

        final buttons = find.byType(OutlinedButton);
        expect(buttons, findsNWidgets(2));

        await tester.tap(buttons.at(0));
        await tester.pumpAndSettle();
        await tester.tap(buttons.at(1));
        await tester.pumpAndSettle();

        expect(tappedUrls, hasLength(2));
        expect(tappedUrls[0], contains('idp.example.com/authorize'));
        expect(tappedUrls[1], contains('idp.example.com/sso'));
      },
    );

    testWidgets('OIDC social login discovers the endpoint and reports state', (
      tester,
    ) async {
      SocialProvider? tappedProvider;
      final client = MockClient((request) async {
        return http.Response(
          json.encode({
            'authorization_endpoint': 'https://idp.example.com/authorize',
          }),
          200,
        );
      });

      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            httpClient: client,
            socialProviders: const [
              OIDCProvider(
                issuerUrl: 'https://idp.example.com',
                clientId: 'client-x',
              ),
            ],
            onSocialLoginInitiated: (provider, state, codeVerifier) {
              tappedProvider = provider;
            },
            onLinkTap: (_) {},
          ),
        ),
      );

      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(tappedProvider, isA<OIDCProvider>());
    });

    testWidgets(
      'a social login failure (e.g. OIDC discovery failing) shows an error '
      'without crashing',
      (tester) async {
        final client = MockClient((request) async {
          return http.Response('discovery down', 500);
        });

        await tester.pumpWidget(
          _wrap(
            LoginPageBuilder(
              apiConfig: LoginApiConfig(
                loginUrl: 'https://api.example.com/login',
              ),
              branding: const BrandingConfig(appName: 'Test App'),
              httpClient: client,
              socialProviders: const [
                OIDCProvider(
                  issuerUrl: 'https://idp.example.com',
                  clientId: 'client-x',
                ),
              ],
            ),
          ),
        );

        await tester.tap(find.byType(OutlinedButton));
        await tester.pumpAndSettle();

        expect(
          find.text('Unable to start social login. Please try again.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('toggling Remember Me updates the checkbox state', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
          ),
        ),
      );

      final checkboxFinder = find.byType(Checkbox);
      expect(tester.widget<Checkbox>(checkboxFinder).value, isFalse);

      await tester.tap(checkboxFinder);
      await tester.pump();

      expect(tester.widget<Checkbox>(checkboxFinder).value, isTrue);
    });

    testWidgets('Forgot password callback is invoked when provided', (
      tester,
    ) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            // The Remember Me checkbox and this link share a row that's too
            // narrow for both at once — not this test's concern.
            showRememberMe: false,
            forgotPasswordCallback: () => called = true,
          ),
        ),
      );

      await tester.tap(find.text('Forgot password?'));
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('Forgot password url is routed through onLinkTap when set', (
      tester,
    ) async {
      String? tapped;
      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            showRememberMe: false,
            forgotPasswordUrl: 'https://example.com/forgot',
            onLinkTap: (url) => tapped = url,
          ),
        ),
      );

      await tester.tap(find.text('Forgot password?'));
      await tester.pump();

      expect(tapped, 'https://example.com/forgot');
    });

    testWidgets(
      'Forgot password url launches externally and shows an error if it '
      'could not be opened',
      (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_urlLauncherChannel, (call) async {
              if (call.method == 'launch') return false;
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(_urlLauncherChannel, null);
        });

        await tester.pumpWidget(
          _wrap(
            LoginPageBuilder(
              apiConfig: LoginApiConfig(
                loginUrl: 'https://api.example.com/login',
              ),
              branding: const BrandingConfig(appName: 'Test App'),
              showRememberMe: false,
              forgotPasswordUrl: 'https://example.com/forgot',
            ),
          ),
        );

        await tester.tap(find.text('Forgot password?'));
        await tester.pumpAndSettle();

        expect(find.text('Could not open the link.'), findsOneWidget);
      },
    );

    testWidgets('Sign up callback is invoked when provided', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            signUpCallback: () => called = true,
          ),
        ),
      );

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Sign up'),
        ),
      );
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('Sign up url is routed through onLinkTap when set', (
      tester,
    ) async {
      String? tapped;
      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            signUpUrl: 'https://example.com/signup',
            onLinkTap: (url) => tapped = url,
          ),
        ),
      );

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Sign up'),
        ),
      );
      await tester.pump();

      expect(tapped, 'https://example.com/signup');
    });

    testWidgets('Sign up url launches externally when no onLinkTap is set', (
      tester,
    ) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_urlLauncherChannel, (call) async {
            calls.add(call);
            if (call.method == 'launch') return true;
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_urlLauncherChannel, null);
      });

      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            signUpUrl: 'https://example.com/signup',
          ),
        ),
      );

      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is RichText && w.text.toPlainText().contains('Sign up'),
        ),
      );
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      final args = calls.single.arguments as Map<Object?, Object?>;
      expect(args['url'], 'https://example.com/signup');
    });

    testWidgets('verifying the MFA code retries login with the code', (
      tester,
    ) async {
      var loginCallCount = 0;
      String? capturedMfaCode;
      final client = MockClient((request) async {
        loginCallCount++;
        if (loginCallCount == 1) {
          return http.Response(
            json.encode({'success': false, 'mfaRequired': true}),
            200,
          );
        }
        final body = json.decode(request.body) as Map<String, dynamic>;
        capturedMfaCode = body['mfaCode'] as String?;
        return http.Response(
          json.encode({'success': true, 'token': 'access-token'}),
          200,
        );
      });

      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            mfaConfig: const MFAConfig(enabled: true, codeLength: 4),
            httpClient: client,
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Two-Factor Authentication'), findsOneWidget);

      final codeFields = find.descendant(
        of: find.byType(MFAModal),
        matching: find.byType(TextField),
      );
      for (var i = 0; i < 4; i++) {
        await tester.enterText(codeFields.at(i), '$i');
        await tester.pump();
      }
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pumpAndSettle();

      expect(capturedMfaCode, '0123');
      expect(find.text('Two-Factor Authentication'), findsNothing);
    });

    testWidgets('cancelling the MFA modal dismisses it', (tester) async {
      final client = MockClient((request) async {
        return http.Response(
          json.encode({'success': false, 'mfaRequired': true}),
          200,
        );
      });

      await tester.pumpWidget(
        _wrap(
          LoginPageBuilder(
            apiConfig: LoginApiConfig(
              loginUrl: 'https://api.example.com/login',
            ),
            branding: const BrandingConfig(appName: 'Test App'),
            mfaConfig: const MFAConfig(enabled: true),
            httpClient: client,
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Two-Factor Authentication'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pump();

      expect(find.text('Two-Factor Authentication'), findsNothing);
    });

    testWidgets(
      'shows the GDPR cookie consent banner and Accept All dismisses it, '
      'notifying the page to rebuild',
      (tester) async {
        SharedPreferences.setMockInitialValues({});

        await tester.pumpWidget(
          _wrap(
            LoginPageBuilder(
              apiConfig: LoginApiConfig(
                loginUrl: 'https://api.example.com/login',
              ),
              branding: const BrandingConfig(appName: 'Test App'),
              gdprConfig: const GDPRConfig(
                privacyPolicyUrl: 'https://example.com/privacy',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CookieConsentBanner), findsOneWidget);

        await tester.tap(find.text('Accept All'));
        await tester.pumpAndSettle();

        expect(find.byType(CookieConsentBanner), findsNothing);
      },
    );
  });
}
