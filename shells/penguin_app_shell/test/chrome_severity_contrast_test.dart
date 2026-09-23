import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_offline/penguin_offline.dart';
import 'package:penguin_testing/penguin_testing.dart';
import 'package:penguin_ui/penguin_ui.dart';

/// WCAG 2.1 relative-luminance contrast ratio — the same formula the W3C
/// contrast checker uses — computed from `Color.computeLuminance()` per
/// this fix round's explicit instruction, never eyeballed from a PNG.
double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance() + 0.05;
  final l2 = b.computeLuminance() + 0.05;
  return l1 > l2 ? l1 / l2 : l2 / l1;
}

/// The actually-*painted* foreground color of the text found by [finder]
/// — reads the resolved `RenderParagraph`'s `TextStyle.color` rather than
/// a `Text` widget's own (frequently-null, inherited-from-ancestor)
/// `style` field, so a `TextButtonTheme`/`DefaultTextStyle` override
/// (exactly what `DeadLetterNotice`'s Retry/Dismiss buttons rely on) is
/// reflected precisely as rendered, not approximated.
Color _renderedTextColor(WidgetTester tester, Finder finder) {
  final richText = tester.widget<RichText>(
    find.descendant(of: finder, matching: find.byType(RichText)).first,
  );
  final color = richText.text.style?.color;
  expect(color, isNotNull, reason: 'expected a resolved text color');
  return color!;
}

AppConfig _config() => AppConfig(
  productKey: 'product',
  appVersion: '1.0.0',
  environment: PenguinEnvironment.beta,
  apiBaseUrl: Uri.parse('https://api.product.example'),
  licenseServerUrl: 'https://license.penguintech.io',
);

SyncQueue _queueWithOneDeadLetter() {
  final db = OfflineDatabase.inMemory();
  final api = PenguinApiClient(
    config: _config(),
    tokens: FakeTokenProvider(initialToken: 'tok'),
    inner: ScriptedHttpClient()..queueResponse(statusCode: 422, body: '{}'),
  );
  return SyncQueue(
    db: db,
    api: api,
    connectivity: FakeConnectivityMonitor(),
    log: ConsoleLogger(),
  );
}

Future<void> _pumpDeadLetterNotice(WidgetTester tester, ThemeData theme) async {
  final queue = _queueWithOneDeadLetter();
  await queue.enqueue(
    PendingWrite(
      id: 'w1',
      method: 'POST',
      path: '/x',
      createdAt: DateTime.now(),
    ),
  );
  await queue.drain();
  addTearDown(queue.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [syncQueueProvider.overrideWithValue(queue)],
      child: MaterialApp(
        theme: theme,
        home: const Scaffold(body: DeadLetterNotice()),
      ),
    ),
  );
  // The startup backlog resolves via a `Future`, then a `setState`.
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpConnectivityBanner(
  WidgetTester tester,
  ThemeData theme,
) async {
  final monitor = FakeConnectivityMonitor();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [connectivityMonitorProvider.overrideWithValue(monitor)],
      child: MaterialApp(
        theme: theme,
        home: const Scaffold(body: ConnectivityBanner()),
      ),
    ),
  );
  await tester.pump();
  // The status stream is broadcast — setStatus before the first pump's
  // subscription would be lost, so it must follow the initial pump. Two
  // pumps: one to deliver the stream event, one for the rebuild it queues.
  monitor.setStatus(ConnectivityStatus.offline);
  await tester.pump();
  await tester.pump();
}

void main() {
  for (final themeEntry in <String, ThemeData>{
    'dark': PenguinTheme.dark(),
    'light': PenguinTheme.light(),
  }.entries) {
    final themeName = themeEntry.key;
    final theme = themeEntry.value;

    group('$themeName theme', () {
      testWidgets(
        'DeadLetterNotice: background/text/Retry/Dismiss all meet 4.5:1',
        (tester) async {
          await _pumpDeadLetterNotice(tester, theme);

          final material = tester.widget<Material>(
            find
                .descendant(
                  of: find.byType(DeadLetterNotice),
                  matching: find.byType(Material),
                )
                .first,
          );
          final background = material.color;
          expect(background, isNotNull);

          final bodyTextColor = _renderedTextColor(
            tester,
            find.text("A change couldn't be saved"),
          );
          expect(
            _contrastRatio(background!, bodyTextColor),
            greaterThanOrEqualTo(4.5),
            reason: 'DeadLetterNotice body text vs its background',
          );

          final retryColor = _renderedTextColor(
            tester,
            find.widgetWithText(TextButton, 'Retry'),
          );
          expect(
            _contrastRatio(background, retryColor),
            greaterThanOrEqualTo(4.5),
            reason: 'DeadLetterNotice Retry button label vs its background',
          );

          final dismissColor = _renderedTextColor(
            tester,
            find.widgetWithText(TextButton, 'Dismiss'),
          );
          expect(
            _contrastRatio(background, dismissColor),
            greaterThanOrEqualTo(4.5),
            reason: 'DeadLetterNotice Dismiss button label vs its background',
          );
        },
      );

      testWidgets('ConnectivityBanner: background/text meet 4.5:1', (
        tester,
      ) async {
        await _pumpConnectivityBanner(tester, theme);

        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(ConnectivityBanner),
                matching: find.byType(Material),
              )
              .first,
        );
        final background = material.color;
        expect(background, isNotNull);

        final textColor = _renderedTextColor(
          tester,
          find.textContaining('Offline'),
        );
        expect(
          _contrastRatio(background!, textColor),
          greaterThanOrEqualTo(4.5),
          reason: 'ConnectivityBanner text vs its background',
        );
      });

      testWidgets(
        'DeadLetterNotice and ConnectivityBanner use different backgrounds',
        (tester) async {
          // Stacked in one tree together (as `AppChrome` actually renders
          // them), not pumped one after another — reusing one
          // `ProviderScope` element across two unrelated override sets
          // trips Riverpod's "update override of a provider that was not
          // overridden before" assertion.
          final monitor = FakeConnectivityMonitor();
          final queue = _queueWithOneDeadLetter();
          await queue.enqueue(
            PendingWrite(
              id: 'w1',
              method: 'POST',
              path: '/x',
              createdAt: DateTime.now(),
            ),
          );
          await queue.drain();
          addTearDown(queue.dispose);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                connectivityMonitorProvider.overrideWithValue(monitor),
                syncQueueProvider.overrideWithValue(queue),
              ],
              child: MaterialApp(
                theme: theme,
                home: const Scaffold(
                  body: Column(
                    children: [ConnectivityBanner(), DeadLetterNotice()],
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          monitor.setStatus(ConnectivityStatus.offline);
          await tester.pump();
          await tester.pump();

          final bannerMaterial = tester.widget<Material>(
            find
                .descendant(
                  of: find.byType(ConnectivityBanner),
                  matching: find.byType(Material),
                )
                .first,
          );
          final noticeMaterial = tester.widget<Material>(
            find
                .descendant(
                  of: find.byType(DeadLetterNotice),
                  matching: find.byType(Material),
                )
                .first,
          );

          expect(
            bannerMaterial.color,
            isNot(equals(noticeMaterial.color)),
            reason:
                'offline (informational) and failed-sync (error) must not '
                'render as the same color',
          );
        },
      );
    });
  }
}
