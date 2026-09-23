import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

class _ScriptedLauncher implements UrlLauncher {
  _ScriptedLauncher(this.results);

  final List<bool> results;
  final List<Uri> launchCalls = [];

  @override
  Future<bool> launch(Uri uri) async {
    launchCalls.add(uri);
    return results.removeAt(0);
  }
}

class _ThrowingLauncher implements UrlLauncher {
  @override
  Future<bool> launch(Uri uri) async => throw StateError('boom');
}

class _RecordingMetricsSink implements MetricsSink {
  final List<(String, num, Map<String, Object?>)> counters = [];

  @override
  void counter(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  }) {
    counters.add((name, value, attributes));
  }

  @override
  void histogram(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  }) {}

  @override
  void gauge(
    String name,
    num value, {
    Map<String, Object?> attributes = const {},
  }) {}
}

class _RecordingSpan implements SpanHandle {
  final Map<String, Object?> attributes = {};
  bool ended = false;

  @override
  void setAttribute(String key, Object? value) => attributes[key] = value;

  @override
  void recordError(Object error, [StackTrace? stack]) {}

  @override
  void end() => ended = true;

  @override
  String get traceparent => '';
}

class _RecordingTraceSink implements TraceSink {
  final List<_RecordingSpan> spans = [];

  @override
  SpanHandle startSpan(
    String name, {
    SpanHandle? parent,
    Map<String, Object?> attributes = const {},
  }) {
    final span = _RecordingSpan();
    spans.add(span);
    return span;
  }
}

const _waddles = SiblingApp(
  id: 'waddles',
  displayName: 'Waddles',
  applicationId: 'io.penguintech.waddles',
  scheme: 'io.penguintech.waddles',
);

void main() {
  group('SiblingApp', () {
    test('a non-const instance carries the given fields', () {
      final app = SiblingApp(
        id: 'ruffled',
        displayName: 'Ruffled',
        applicationId: 'io.penguintech.ruffled',
        scheme: 'io.penguintech.ruffled',
      );
      expect(app.id, 'ruffled');
      expect(app.displayName, 'Ruffled');
      expect(app.applicationId, 'io.penguintech.ruffled');
      expect(app.scheme, 'io.penguintech.ruffled');
    });

    test(
      'deepLink builds a scheme://open/<route> uri, normalizing a missing leading slash',
      () {
        expect(
          _waddles.deepLink('/home').toString(),
          'io.penguintech.waddles://open/home',
        );
        expect(
          _waddles.deepLink('home').toString(),
          'io.penguintech.waddles://open/home',
        );
      },
    );

    test('storeUri points at the market listing for applicationId', () {
      expect(
        _waddles.storeUri.toString(),
        'market://details?id=io.penguintech.waddles',
      );
    });
  });

  group('NoopUrlLauncher', () {
    test('always reports it cannot launch anything', () async {
      const launcher = NoopUrlLauncher();
      expect(await launcher.launch(Uri.parse('https://example.com')), isFalse);
    });
  });

  group('UrlLauncherAdapter', () {
    test(
      'calls the injected launchUrl function with externalApplication mode',
      () async {
        Uri? seenUrl;
        LaunchMode? seenMode;
        final adapter = UrlLauncherAdapter(
          launchUrlFn: (url, {mode = LaunchMode.platformDefault}) async {
            seenUrl = url;
            seenMode = mode;
            return true;
          },
        );
        final uri = Uri.parse('io.penguintech.waddles://open/home');
        expect(await adapter.launch(uri), isTrue);
        expect(seenUrl, uri);
        expect(seenMode, LaunchMode.externalApplication);
      },
    );

    test(
      'returns false when the injected function reports it could not launch',
      () async {
        final adapter = UrlLauncherAdapter(
          launchUrlFn: (url, {mode = LaunchMode.platformDefault}) async =>
              false,
        );
        expect(
          await adapter.launch(Uri.parse('io.penguintech.waddles://open/home')),
          isFalse,
        );
      },
    );

    test(
      'propagates an exception from the injected function to the caller',
      () async {
        final adapter = UrlLauncherAdapter(
          launchUrlFn: (url, {mode = LaunchMode.platformDefault}) async =>
              throw StateError('platform exception'),
        );
        await expectLater(
          adapter.launch(Uri.parse('io.penguintech.waddles://open/home')),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'defaults to the real url_launcher.launchUrl, which throws with no platform channel registered',
      () async {
        // The real launchUrl needs a MethodChannel binding to even attempt
        // (and then fail with MissingPluginException, not throw a raw
        // "binding not initialized" error) — this test is otherwise a
        // plain, non-widget test. UrlLauncherAdapter itself does not catch
        // this — SiblingAppLauncher is the layer that turns a thrown
        // exception into a store fallback (see the group below).
        TestWidgetsFlutterBinding.ensureInitialized();
        const adapter = UrlLauncherAdapter();
        await expectLater(
          adapter.launch(Uri.parse('io.penguintech.waddles://open/home')),
          throwsA(isA<MissingPluginException>()),
        );
      },
    );
  });

  group('SiblingAppLauncher', () {
    test('opens the deep link when it can be launched', () async {
      final launcher = _ScriptedLauncher([true]);
      final metrics = _RecordingMetricsSink();
      final traces = _RecordingTraceSink();
      final result = await SiblingAppLauncher(
        launcher: launcher,
        metrics: metrics,
        traces: traces,
      ).open(_waddles, route: '/home');

      expect(result, LaunchOutcome.opened);
      expect(launcher.launchCalls.single, _waddles.deepLink('/home'));
      expect(metrics.counters.single.$1, 'sibling_app.launch');
      expect(metrics.counters.single.$3['outcome'], 'opened');
      expect(traces.spans.single.attributes['outcome'], 'opened');
      expect(traces.spans.single.ended, isTrue);
    });

    test('falls back to the store when the deep link returns false', () async {
      final launcher = _ScriptedLauncher([false, true]);
      final result = await SiblingAppLauncher(
        launcher: launcher,
      ).open(_waddles);
      expect(result, LaunchOutcome.sentToStore);
      expect(launcher.launchCalls.last, _waddles.storeUri);
    });

    test('falls back to the store when the deep link throws', () async {
      final launcher = _ThrowingOnceThenScriptedLauncher();
      final result = await SiblingAppLauncher(
        launcher: launcher,
      ).open(_waddles);
      expect(result, LaunchOutcome.sentToStore);
      expect(launcher.calls, 2);
    });

    test(
      'reports failed and logs a warning when both the deep link and the store fail',
      () async {
        final launcher = _ScriptedLauncher([false, false]);
        final metrics = _RecordingMetricsSink();
        final result = await SiblingAppLauncher(
          launcher: launcher,
          metrics: metrics,
        ).open(_waddles);
        expect(result, LaunchOutcome.failed);
        expect(metrics.counters.single.$3['outcome'], 'failed');
      },
    );

    test('never throws even when the launcher always throws', () async {
      final launcher = SiblingAppLauncher(launcher: _ThrowingLauncher());
      final result = await launcher.open(_waddles);
      expect(result, LaunchOutcome.failed);
    });

    test(
      'defaults to the real UrlLauncherAdapter, which fails gracefully with no platform channel registered',
      () async {
        TestWidgetsFlutterBinding.ensureInitialized();
        final launcher = SiblingAppLauncher();
        final result = await launcher.open(_waddles);
        expect(result, LaunchOutcome.failed);
      },
    );
  });
}

/// Throws on its first call (simulating the deep link failing with a
/// platform exception), then succeeds on the second (the store fallback).
class _ThrowingOnceThenScriptedLauncher implements UrlLauncher {
  int calls = 0;

  @override
  Future<bool> launch(Uri uri) async {
    calls++;
    if (calls == 1) throw StateError('boom');
    return true;
  }
}
