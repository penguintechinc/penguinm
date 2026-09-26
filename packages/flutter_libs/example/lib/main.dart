import 'package:flutter/material.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  runApp(const ExampleApp());
}

/// Root widget for the flutter_libs example application.
class ExampleApp extends StatelessWidget {
  /// Creates an [ExampleApp].
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Libs Example',
      theme: ThemeData.dark().copyWith(extensions: [ElderThemeData.dark]),
      home: const ExampleHome(),
    );
  }
}

/// Home page demonstrating flutter_libs components.
class ExampleHome extends StatelessWidget {
  /// Creates an [ExampleHome].
  const ExampleHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Libs Example'),
        backgroundColor: ElderColors.slate800,
      ),
      backgroundColor: ElderColors.slate900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => _showFormModal(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: ElderColors.amber500,
                foregroundColor: ElderColors.slate900,
              ),
              child: const Text('Open Form Modal'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(builder: (_) => const LoginExample()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ElderColors.amber500,
                foregroundColor: ElderColors.slate900,
              ),
              child: const Text('View Login Page'),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays a form modal for creating an item.
  void _showFormModal(BuildContext context) {
    FormModalBuilder.show(
      context: context,
      title: 'Create Item',
      fields: [
        const FormFieldConfig(
          name: 'name',
          label: 'Name',
          type: FormFieldType.text,
          required: true,
          placeholder: 'Enter item name',
        ),
        const FormFieldConfig(
          name: 'description',
          label: 'Description',
          type: FormFieldType.textarea,
        ),
        const FormFieldConfig(
          name: 'category',
          label: 'Category',
          type: FormFieldType.select,
          options: [
            FormFieldOption(label: 'General', value: 'general'),
            FormFieldOption(label: 'Technical', value: 'technical'),
          ],
        ),
      ],
      onSubmit: (values) async {
        debugPrint('Form submitted: $values');
      },
    );
  }
}

/// Demonstrates [LoginPageBuilder] wired up with social login (PKCE/CSRF
/// state handling via `onSocialLoginInitiated`) and secure token storage.
class LoginExample extends StatefulWidget {
  /// Creates a [LoginExample].
  const LoginExample({super.key});

  @override
  State<LoginExample> createState() => _LoginExampleState();
}

/// State for [LoginExample] demonstrating login flow with OAuth.
class _LoginExampleState extends State<LoginExample> {
  /// Persists tokens to the platform Keychain/Keystore on a successful
  /// login. Call `_tokenStorage.clear()` wherever your app implements
  /// logout — this widget has no logout UI of its own.
  final _tokenStorage = TokenStorage();

  /// In-memory holder for the pending OAuth CSRF `state`. A real app would
  /// persist this (e.g. secure storage keyed by `state`) so it survives
  /// the process being backgrounded while the browser is open, then read
  /// it back in the deep-link/callback handler to validate against the
  /// returned state via `isValidCallbackState`.
  String? _pendingOAuthState;

  /// In-memory holder for the pending PKCE `codeVerifier`, saved and
  /// restored alongside [_pendingOAuthState] and used to complete the
  /// token exchange once the callback handler validates the state.
  String? _pendingCodeVerifier;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        LoginPageBuilder(
          apiConfig: LoginApiConfig(
            loginUrl: 'https://api.example.com/auth/login',
          ),
          branding: const BrandingConfig(
            appName: 'Example App',
            tagline: 'Welcome back! Please sign in.',
          ),
          socialProviders: const [
            BuiltInOAuth2Provider(
              provider: BuiltInProviderType.google,
              clientId: 'your-google-client-id',
              redirectUri: 'https://example.com/auth/callback',
            ),
          ],
          tokenStorage: _tokenStorage,
          onSocialLoginInitiated: (provider, state, codeVerifier) {
            // Called just before launching the provider's authorization
            // URL. Stash state/codeVerifier now; your deep-link handler
            // for `redirectUri` should call
            // isValidCallbackState(_pendingOAuthState, returnedState)
            // before exchanging the authorization code using
            // _pendingCodeVerifier — see _handleOAuthCallback below.
            _pendingOAuthState = state;
            _pendingCodeVerifier = codeVerifier;
            debugPrint(
              '[LoginExample] social login initiated { provider: '
              '${provider.runtimeType} }',
            );
          },
          onLoginSuccess: (response) {
            debugPrint('Login success: ${response.user?.email}');
            Navigator.pop(context);
          },
          onLoginError: (error) {
            debugPrint('Login error: $error');
          },
        ),

        // Debug-only stand-in for your real deep-link handler firing after
        // the browser redirects back with `state` + `code`. A real app
        // wires _handleOAuthCallback to uni_links/app_links instead of a
        // button.
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.small(
            heroTag: 'simulate-oauth-callback',
            tooltip: 'Simulate OAuth callback (debug)',
            backgroundColor: ElderColors.slate700,
            onPressed: () => _handleOAuthCallback(
              returnedState: _pendingOAuthState ?? '',
              authorizationCode: 'debug-authorization-code',
            ),
            child: const Icon(Icons.bug_report, color: ElderColors.amber400),
          ),
        ),
      ],
    );
  }

  /// Illustrates the deep-link/callback handler your app registers for
  /// [BuiltInOAuth2Provider.redirectUri]. Wire your actual
  /// `uni_links`/`app_links` (or platform channel) callback to call
  /// something like this with the provider's returned `state` and
  /// authorization `code`.
  Future<void> _handleOAuthCallback({
    required String returnedState,
    required String authorizationCode,
  }) async {
    final expectedState = _pendingOAuthState;
    final codeVerifier = _pendingCodeVerifier;
    if (expectedState == null || codeVerifier == null) {
      debugPrint('[LoginExample] OAuth callback with no pending request');
      return;
    }
    if (!isValidCallbackState(expectedState, returnedState)) {
      debugPrint('[LoginExample] OAuth callback state mismatch — rejecting');
      return;
    }
    // Exchange `authorizationCode` + `codeVerifier` for tokens with your
    // backend here, then persist via `_tokenStorage.saveTokens(...)`.
    debugPrint(
      '[LoginExample] OAuth callback validated, ready to exchange '
      'code (verifier length: ${codeVerifier.length})',
    );
    _pendingOAuthState = null;
    _pendingCodeVerifier = null;
  }
}
