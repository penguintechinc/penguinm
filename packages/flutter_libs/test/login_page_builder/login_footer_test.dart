import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';
import 'package:url_launcher/url_launcher.dart';

const _urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoginFooter', () {
    testWidgets('renders nothing when no links or copyright are set', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoginFooter())),
      );

      expect(find.text('GitHub'), findsNothing);
      expect(find.text('Privacy Policy'), findsNothing);
      expect(find.text('Terms of Service'), findsNothing);
      expect(find.byType(Wrap), findsNothing);
    });

    testWidgets('shows a GitHub link and reports taps via onLinkTap', (
      tester,
    ) async {
      String? tappedUrl;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginFooter(
              githubRepo: 'https://github.com/penguintechinc/penguinm',
              onLinkTap: (url) => tappedUrl = url,
            ),
          ),
        ),
      );

      expect(find.text('GitHub'), findsOneWidget);
      await tester.tap(find.text('GitHub'));
      await tester.pump();

      expect(tappedUrl, 'https://github.com/penguintechinc/penguinm');
    });

    testWidgets('shows a Privacy Policy link and reports taps', (tester) async {
      String? tappedUrl;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginFooter(
              privacyPolicyUrl: 'https://example.com/privacy',
              onLinkTap: (url) => tappedUrl = url,
            ),
          ),
        ),
      );

      expect(find.text('Privacy Policy'), findsOneWidget);
      await tester.tap(find.text('Privacy Policy'));
      await tester.pump();

      expect(tappedUrl, 'https://example.com/privacy');
    });

    testWidgets('shows a Terms of Service link and reports taps', (
      tester,
    ) async {
      String? tappedUrl;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginFooter(
              termsUrl: 'https://example.com/terms',
              onLinkTap: (url) => tappedUrl = url,
            ),
          ),
        ),
      );

      expect(find.text('Terms of Service'), findsOneWidget);
      await tester.tap(find.text('Terms of Service'));
      await tester.pump();

      expect(tappedUrl, 'https://example.com/terms');
    });

    testWidgets('shows all three links together', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoginFooter(
              githubRepo: 'https://github.com/penguintechinc/penguinm',
              privacyPolicyUrl: 'https://example.com/privacy',
              termsUrl: 'https://example.com/terms',
            ),
          ),
        ),
      );

      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('shows copyright text when set', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoginFooter(copyrightText: '© 2026 PenguinTech'),
          ),
        ),
      );

      expect(find.text('© 2026 PenguinTech'), findsOneWidget);
    });

    testWidgets('applies custom text and link colors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoginFooter(
              githubRepo: 'https://github.com/penguintechinc/penguinm',
              copyrightText: '© 2026 PenguinTech',
              textColor: Colors.pink,
              linkColor: Colors.cyan,
            ),
          ),
        ),
      );

      final linkText = tester.widget<Text>(find.text('GitHub'));
      expect(linkText.style?.color, Colors.cyan);
      final copyrightWidget = tester.widget<Text>(
        find.text('© 2026 PenguinTech'),
      );
      expect(copyrightWidget.style?.color, Colors.pink);
    });

    testWidgets('tapping a link is a no-op when onLinkTap is not set', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LoginFooter(
              githubRepo: 'https://github.com/penguintechinc/penguinm',
            ),
          ),
        ),
      );

      await tester.tap(find.text('GitHub'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('a real onLinkTap wired to url_launcher invokes the platform '
        'channel with the tapped url', (tester) async {
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
        MaterialApp(
          home: Scaffold(
            body: LoginFooter(
              githubRepo: 'https://github.com/penguintechinc/penguinm',
              onLinkTap: (url) async {
                await launchUrl(Uri.parse(url));
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('GitHub'));
      await tester.pumpAndSettle();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'launch');
      final arguments = calls.single.arguments as Map<Object?, Object?>;
      expect(arguments['url'], 'https://github.com/penguintechinc/penguinm');
    });
  });
}
