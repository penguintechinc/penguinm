import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_update/penguin_update.dart';

/// Asserts the platform channel received a `launch` call whose `url`
/// argument matches [expected] exactly — not just that some call happened.
void expectLaunchedUrl(List<MethodCall> calls, String expected) {
  final launchCalls = calls.where((c) => c.method == 'launch').toList();
  expect(
    launchCalls,
    isNotEmpty,
    reason: 'expected a "launch" platform call, got: $calls',
  );
  expect((launchCalls.single.arguments as Map)['url'], equals(expected));
}

void main() {
  group('UpdatePrompt URL launcher platform channel', () {
    late MethodChannel urlLauncherChannel;
    late List<MethodCall> methodCalls;

    setUp(() {
      urlLauncherChannel = const MethodChannel(
        'plugins.flutter.io/url_launcher',
      );
      methodCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(urlLauncherChannel, (call) async {
            methodCalls.add(call);
            return true; // canLaunch => true, launch => success
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(urlLauncherChannel, null);
    });

    testWidgets(
      'banner launches the exact info.storeUrl when Update is tapped',
      (WidgetTester tester) async {
        final expectedUrl = Uri.parse(
          'https://play.google.com/store/apps/details?id=io.penguintech.test',
        );
        final versionInfo = ClientVersionInfo(
          latestVersion: '2.0.0',
          storeUrl: expectedUrl,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UpdatePrompt(
                applicationId: 'io.penguintech.test',
                status: UpdateAvailable(versionInfo),
              ),
            ),
          ),
        );

        await tester.tap(find.widgetWithText(TextButton, 'Update'));
        await tester.pumpAndSettle();

        expectLaunchedUrl(methodCalls, expectedUrl.toString());
      },
    );

    testWidgets(
      'banner launches the market:// fallback when storeUrl is null',
      (WidgetTester tester) async {
        final versionInfo = ClientVersionInfo(
          latestVersion: '2.0.0',
          storeUrl: null,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UpdatePrompt(
                applicationId: 'io.penguintech.test',
                status: UpdateAvailable(versionInfo),
              ),
            ),
          ),
        );

        await tester.tap(find.widgetWithText(TextButton, 'Update'));
        await tester.pumpAndSettle();

        expectLaunchedUrl(
          methodCalls,
          'market://details?id=io.penguintech.test',
        );
      },
    );

    testWidgets(
      'required dialog launches the exact info.storeUrl when Update is tapped',
      (WidgetTester tester) async {
        final expectedUrl = Uri.parse(
          'https://play.google.com/store/apps/details?id=io.penguintech.test',
        );
        final versionInfo = ClientVersionInfo(
          latestVersion: '2.0.0',
          minimumVersion: '2.0.0',
          storeUrl: expectedUrl,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UpdatePrompt(
                applicationId: 'io.penguintech.test',
                status: UpdateRequired(versionInfo),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Update'));
        await tester.pumpAndSettle();

        expectLaunchedUrl(methodCalls, expectedUrl.toString());
      },
    );

    testWidgets(
      'required dialog launches the market:// fallback when storeUrl is null',
      (WidgetTester tester) async {
        final versionInfo = ClientVersionInfo(
          latestVersion: '2.0.0',
          minimumVersion: '2.0.0',
          storeUrl: null,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UpdatePrompt(
                applicationId: 'io.penguintech.test',
                status: UpdateRequired(versionInfo),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Update'));
        await tester.pumpAndSettle();

        expectLaunchedUrl(
          methodCalls,
          'market://details?id=io.penguintech.test',
        );
      },
    );

    testWidgets(
      'does not throw and shows no launch call when canLaunch reports false',
      (WidgetTester tester) async {
        // canLaunch => false short-circuits _launchStore before it ever
        // calls launch.
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(urlLauncherChannel, (call) async {
              methodCalls.add(call);
              return false;
            });

        final versionInfo = ClientVersionInfo(
          latestVersion: '2.0.0',
          storeUrl: Uri.parse('https://example.com/app'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UpdatePrompt(
                applicationId: 'io.penguintech.test',
                status: UpdateAvailable(versionInfo),
              ),
            ),
          ),
        );

        await tester.tap(find.widgetWithText(TextButton, 'Update'));
        await tester.pumpAndSettle();

        expect(methodCalls.any((c) => c.method == 'canLaunch'), isTrue);
        expect(methodCalls.any((c) => c.method == 'launch'), isFalse);
        expect(find.byType(UpdatePrompt), findsOneWidget);
      },
    );

    testWidgets(
      'does not throw when canLaunch succeeds but launch itself fails',
      (WidgetTester tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(urlLauncherChannel, (call) async {
              methodCalls.add(call);
              // canLaunch reports the app can be handled, but the actual
              // launch attempt fails (returns false).
              return call.method == 'canLaunch' ? true : false;
            });

        final versionInfo = ClientVersionInfo(
          latestVersion: '2.0.0',
          storeUrl: Uri.parse('https://example.com/app'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UpdatePrompt(
                applicationId: 'io.penguintech.test',
                status: UpdateAvailable(versionInfo),
              ),
            ),
          ),
        );

        await tester.tap(find.widgetWithText(TextButton, 'Update'));
        await tester.pumpAndSettle();

        expect(methodCalls.any((c) => c.method == 'launch'), isTrue);
        expect(find.byType(UpdatePrompt), findsOneWidget);
      },
    );

    testWidgets(
      'does not throw when the platform channel throws PlatformException',
      (WidgetTester tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(urlLauncherChannel, (call) async {
              methodCalls.add(call);
              throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
            });

        final versionInfo = ClientVersionInfo(
          latestVersion: '2.0.0',
          storeUrl: Uri.parse('https://example.com/app'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: UpdatePrompt(
                applicationId: 'io.penguintech.test',
                status: UpdateAvailable(versionInfo),
              ),
            ),
          ),
        );

        // Tap should not throw even when the platform channel throws.
        await tester.tap(find.widgetWithText(TextButton, 'Update'));
        await tester.pumpAndSettle();

        expect(find.byType(UpdatePrompt), findsOneWidget);
      },
    );
  });
}
