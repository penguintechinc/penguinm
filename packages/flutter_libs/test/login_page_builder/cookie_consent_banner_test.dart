import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _defaultConsentText =
    'We use cookies to enhance your experience. '
    'By continuing, you agree to our use of cookies.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CookieConsentBanner', () {
    testWidgets('shows the default consent text when none is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CookieConsentBanner(
              onAcceptAll: () {},
              onAcceptEssential: () {},
            ),
          ),
        ),
      );

      expect(find.text(_defaultConsentText), findsOneWidget);
    });

    testWidgets('shows a custom consent text when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CookieConsentBanner(
              onAcceptAll: () {},
              onAcceptEssential: () {},
              consentText: 'Custom cookie message',
            ),
          ),
        ),
      );

      expect(find.text('Custom cookie message'), findsOneWidget);
      expect(find.text(_defaultConsentText), findsNothing);
    });

    testWidgets('shows no policy links when neither url is set', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CookieConsentBanner(
              onAcceptAll: () {},
              onAcceptEssential: () {},
            ),
          ),
        ),
      );

      expect(find.text('Privacy Policy'), findsNothing);
      expect(find.text('Cookie Policy'), findsNothing);
      expect(find.text('  •  '), findsNothing);
    });

    testWidgets('shows only the privacy policy link when set alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CookieConsentBanner(
              onAcceptAll: () {},
              onAcceptEssential: () {},
              privacyPolicyUrl: 'https://example.com/privacy',
            ),
          ),
        ),
      );

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Cookie Policy'), findsNothing);
      expect(find.text('  •  '), findsNothing);
    });

    testWidgets('shows only the cookie policy link when set alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CookieConsentBanner(
              onAcceptAll: () {},
              onAcceptEssential: () {},
              cookiePolicyUrl: 'https://example.com/cookies',
            ),
          ),
        ),
      );

      expect(find.text('Privacy Policy'), findsNothing);
      expect(find.text('Cookie Policy'), findsOneWidget);
      expect(find.text('  •  '), findsNothing);
    });

    testWidgets('shows both links separated by a bullet when both are set', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CookieConsentBanner(
              onAcceptAll: () {},
              onAcceptEssential: () {},
              privacyPolicyUrl: 'https://example.com/privacy',
              cookiePolicyUrl: 'https://example.com/cookies',
            ),
          ),
        ),
      );

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Cookie Policy'), findsOneWidget);
      expect(find.text('  •  '), findsOneWidget);
    });

    testWidgets(
      'tapping the privacy policy link calls onLinkTap with its url',
      (tester) async {
        String? tappedUrl;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CookieConsentBanner(
                onAcceptAll: () {},
                onAcceptEssential: () {},
                privacyPolicyUrl: 'https://example.com/privacy',
                cookiePolicyUrl: 'https://example.com/cookies',
                onLinkTap: (url) => tappedUrl = url,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Privacy Policy'));
        await tester.pump();

        expect(tappedUrl, 'https://example.com/privacy');
      },
    );

    testWidgets('tapping the cookie policy link calls onLinkTap with its url', (
      tester,
    ) async {
      String? tappedUrl;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CookieConsentBanner(
              onAcceptAll: () {},
              onAcceptEssential: () {},
              privacyPolicyUrl: 'https://example.com/privacy',
              cookiePolicyUrl: 'https://example.com/cookies',
              onLinkTap: (url) => tappedUrl = url,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Cookie Policy'));
      await tester.pump();

      expect(tappedUrl, 'https://example.com/cookies');
    });

    testWidgets('tapping a link is a no-op when onLinkTap is not set', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CookieConsentBanner(
              onAcceptAll: () {},
              onAcceptEssential: () {},
              privacyPolicyUrl: 'https://example.com/privacy',
            ),
          ),
        ),
      );

      await tester.tap(find.text('Privacy Policy'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Accept All invokes onAcceptAll', (tester) async {
      var acceptAllCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CookieConsentBanner(
              onAcceptAll: () => acceptAllCalled = true,
              onAcceptEssential: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Accept All'));
      await tester.pump();

      expect(acceptAllCalled, isTrue);
    });

    testWidgets('Essential Only invokes onAcceptEssential', (tester) async {
      var essentialCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CookieConsentBanner(
              onAcceptAll: () {},
              onAcceptEssential: () => essentialCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Essential Only'));
      await tester.pump();

      expect(essentialCalled, isTrue);
    });

    testWidgets('Preferences is shown and invokes onShowPreferences when both '
        'showPreferences and the callback are set', (tester) async {
      var preferencesCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CookieConsentBanner(
              onAcceptAll: () {},
              onAcceptEssential: () {},
              onShowPreferences: () => preferencesCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Preferences'), findsOneWidget);
      await tester.tap(find.text('Preferences'));
      await tester.pump();

      expect(preferencesCalled, isTrue);
    });

    testWidgets('Preferences is hidden when onShowPreferences is not set', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CookieConsentBanner(
              onAcceptAll: () {},
              onAcceptEssential: () {},
            ),
          ),
        ),
      );

      expect(find.text('Preferences'), findsNothing);
    });

    testWidgets(
      'Preferences is hidden when showPreferences is false even with a '
      'callback set',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CookieConsentBanner(
                onAcceptAll: () {},
                onAcceptEssential: () {},
                showPreferences: false,
                onShowPreferences: () {},
              ),
            ),
          ),
        );

        expect(find.text('Preferences'), findsNothing);
      },
    );
  });

  group('CookieConsentBanner + CookieConsentNotifier (persisted state)', () {
    testWidgets('Accept All persists full consent to SharedPreferences', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final notifier = CookieConsentNotifier();
      await notifier.load();
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CookieConsentBanner(
              onAcceptAll: notifier.acceptAll,
              onAcceptEssential: notifier.acceptEssentialOnly,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Accept All'));
      await tester.pumpAndSettle();

      expect(notifier.consent.accepted, isTrue);
      expect(notifier.consent.analytics, isTrue);
      expect(notifier.consent.marketing, isTrue);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('gdpr_consent');
      expect(raw, isNotNull);
      expect(raw, contains('"accepted":true'));
      expect(raw, contains('"analytics":true'));
      expect(raw, contains('"marketing":true'));
    });

    testWidgets('Essential Only persists an accepted-but-minimal consent to '
        'SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final notifier = CookieConsentNotifier();
      await notifier.load();
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CookieConsentBanner(
              onAcceptAll: notifier.acceptAll,
              onAcceptEssential: notifier.acceptEssentialOnly,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Essential Only'));
      await tester.pumpAndSettle();

      expect(notifier.consent.accepted, isTrue);
      expect(notifier.consent.analytics, isFalse);
      expect(notifier.consent.marketing, isFalse);

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('gdpr_consent');
      expect(raw, contains('"accepted":true'));
      expect(raw, contains('"analytics":false'));
      expect(raw, contains('"marketing":false'));
    });

    testWidgets(
      'the customize (Preferences) flow persists chosen category choices',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final notifier = CookieConsentNotifier();
        await notifier.load();
        addTearDown(notifier.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CookieConsentBanner(
                onAcceptAll: notifier.acceptAll,
                onAcceptEssential: notifier.acceptEssentialOnly,
                onShowPreferences: () => notifier.acceptWithPreferences(
                  functional: true,
                  analytics: true,
                  marketing: false,
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Preferences'));
        await tester.pumpAndSettle();

        expect(notifier.consent.accepted, isTrue);
        expect(notifier.consent.functional, isTrue);
        expect(notifier.consent.analytics, isTrue);
        expect(notifier.consent.marketing, isFalse);

        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString('gdpr_consent');
        expect(raw, contains('"functional":true'));
        expect(raw, contains('"analytics":true'));
        expect(raw, contains('"marketing":false'));
      },
    );
  });
}
