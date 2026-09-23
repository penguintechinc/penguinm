import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_libs/flutter_libs.dart';

void main() {
  group('GoogleIcon', () {
    testWidgets('paints at the default 24x24 size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GoogleIcon())),
      );

      final box = tester.getSize(find.byType(GoogleIcon));
      expect(box, const Size(24, 24));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('paints at a custom size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GoogleIcon(size: 40))),
      );

      final box = tester.getSize(find.byType(GoogleIcon));
      expect(box, const Size(40, 40));
    });

    testWidgets('repainting with a fresh painter instance does not throw', (
      tester,
    ) async {
      // Rebuilding in place hands RenderCustomPaint a new _GooglePainter
      // instance and exercises shouldRepaint on the old delegate.
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GoogleIcon())),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GoogleIcon())),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('SocialIconWidget', () {
    testWidgets('defaults to white and size 20', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SocialIconWidget(icon: Icons.star)),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, Icons.star);
      expect(icon.color, Colors.white);
      expect(icon.size, 20);
    });

    testWidgets('honors a custom color and size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SocialIconWidget(
              icon: Icons.star,
              color: Colors.red,
              size: 32,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.color, Colors.red);
      expect(icon.size, 32);
    });
  });

  group('getProviderIcon', () {
    testWidgets('google returns a GoogleIcon at the requested size', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: getProviderIcon('google', size: 28))),
      );

      final googleIcon = tester.widget<GoogleIcon>(find.byType(GoogleIcon));
      expect(googleIcon.size, 28);
    });

    const materialIconProviders = <String, IconData>{
      'github': Icons.code,
      'microsoft': Icons.window,
      'apple': Icons.apple,
      'twitch': Icons.videocam,
      'discord': Icons.chat_bubble,
      'sso': Icons.vpn_key,
      'enterprise': Icons.business,
      'some-unknown-provider': Icons.login,
    };

    for (final entry in materialIconProviders.entries) {
      testWidgets('${entry.key} returns Icon(${entry.value})', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: getProviderIcon(entry.key, size: 22)),
          ),
        );

        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.icon, entry.value);
        expect(icon.color, Colors.white);
        expect(icon.size, 22);
      });
    }
  });
}
