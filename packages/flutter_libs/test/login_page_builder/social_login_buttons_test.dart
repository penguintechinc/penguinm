import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('SocialLoginButtons', () {
    testWidgets('renders nothing for an empty provider list', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialLoginButtons(
              providers: const [],
              onProviderTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Or continue with'), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('renders the divider and a button per built-in provider', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialLoginButtons(
              providers: const [
                BuiltInOAuth2Provider(
                  provider: BuiltInProviderType.google,
                  clientId: 'client-1',
                ),
              ],
              onProviderTap: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Or continue with'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('tapping a button invokes onProviderTap with that provider', (
      tester,
    ) async {
      SocialProvider? tapped;
      const provider = BuiltInOAuth2Provider(
        provider: BuiltInProviderType.github,
        clientId: 'client-2',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialLoginButtons(
              providers: const [provider],
              onProviderTap: (p) => tapped = p,
            ),
          ),
        ),
      );

      await tester.tap(find.text('GitHub'));
      await tester.pump();

      expect(tapped, same(provider));
    });

    testWidgets(
      'CustomOAuth2Provider falls back to the default icon and colors when '
      'unset, and honors overrides when set',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SocialLoginButtons(
                providers: const [
                  CustomOAuth2Provider(
                    authUrl: 'https://example.com/oauth',
                    clientId: 'custom-1',
                    label: 'Custom Default',
                  ),
                  CustomOAuth2Provider(
                    authUrl: 'https://example.com/oauth2',
                    clientId: 'custom-2',
                    label: 'Custom Styled',
                    icon: Icon(Icons.extension),
                    buttonColor: Colors.purple,
                    textColor: Colors.yellow,
                  ),
                ],
                onProviderTap: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Custom Default'), findsOneWidget);
        expect(find.text('Custom Styled'), findsOneWidget);
        expect(find.byIcon(Icons.login), findsOneWidget);
        expect(find.byIcon(Icons.extension), findsOneWidget);

        final styledButton = tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.text('Custom Styled'),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(
          styledButton.style?.backgroundColor?.resolve(<WidgetState>{}),
          Colors.purple,
        );
        expect(
          styledButton.style?.foregroundColor?.resolve(<WidgetState>{}),
          Colors.yellow,
        );
      },
    );

    testWidgets(
      'OIDCProvider falls back to label "SSO" and the sso icon when unset, '
      'and honors overrides when set',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SocialLoginButtons(
                providers: const [
                  OIDCProvider(
                    issuerUrl: 'https://issuer.example.com',
                    clientId: 'oidc-1',
                  ),
                  OIDCProvider(
                    issuerUrl: 'https://issuer2.example.com',
                    clientId: 'oidc-2',
                    label: 'Corp SSO',
                    icon: Icon(Icons.badge),
                    buttonColor: Colors.teal,
                    textColor: Colors.black,
                  ),
                ],
                onProviderTap: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('SSO'), findsOneWidget);
        expect(find.text('Corp SSO'), findsOneWidget);
        expect(find.byIcon(Icons.vpn_key), findsOneWidget);
        expect(find.byIcon(Icons.badge), findsOneWidget);
      },
    );

    testWidgets(
      'SAMLProvider falls back to label "Enterprise SSO" and the enterprise '
      'icon when unset, and honors overrides when set',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SocialLoginButtons(
                providers: const [
                  SAMLProvider(
                    idpSsoUrl: 'https://idp.example.com/sso',
                    entityId: 'entity-1',
                    acsUrl: 'https://sp.example.com/acs',
                  ),
                  SAMLProvider(
                    idpSsoUrl: 'https://idp2.example.com/sso',
                    entityId: 'entity-2',
                    acsUrl: 'https://sp2.example.com/acs',
                    label: 'Okta',
                    icon: Icon(Icons.security),
                    buttonColor: Colors.indigo,
                    textColor: Colors.white,
                  ),
                ],
                onProviderTap: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Enterprise SSO'), findsOneWidget);
        expect(find.text('Okta'), findsOneWidget);
        expect(find.byIcon(Icons.business), findsOneWidget);
        expect(find.byIcon(Icons.security), findsOneWidget);
      },
    );

    testWidgets('honors custom divider and button colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialLoginButtons(
              providers: const [
                BuiltInOAuth2Provider(
                  provider: BuiltInProviderType.discord,
                  clientId: 'client-3',
                ),
              ],
              onProviderTap: (_) {},
              buttonBackground: Colors.deepOrange,
              buttonBorder: Colors.brown,
              buttonText: Colors.lime,
              dividerColor: Colors.cyan,
              dividerTextColor: Colors.pink,
            ),
          ),
        ),
      );

      final dividers = tester.widgetList<Divider>(find.byType(Divider));
      for (final divider in dividers) {
        expect(divider.color, Colors.cyan);
      }
      final dividerText = tester.widget<Text>(find.text('Or continue with'));
      expect(dividerText.style?.color, Colors.pink);
    });
  });
}
