import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_offline/src/widgets/stale_data_chip.dart';

class _FakeClock implements Clock {
  _FakeClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}

void main() {
  Future<void> pumpChip(
    WidgetTester tester,
    DateTime fetchedAt,
    Clock clock,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StaleDataChip(fetchedAt: fetchedAt, clock: clock),
        ),
      ),
    );
  }

  testWidgets('shows "just now" for under a minute', (tester) async {
    final fetchedAt = DateTime(2026, 1, 1, 12, 0, 0);
    await pumpChip(
      tester,
      fetchedAt,
      _FakeClock(fetchedAt.add(const Duration(seconds: 30))),
    );

    expect(find.text('Last synced just now'), findsOneWidget);
  });

  testWidgets(
    'shows "0m ago" at exactly the 60 second boundary is instead minutes',
    (tester) async {
      final fetchedAt = DateTime(2026, 1, 1, 12, 0, 0);
      await pumpChip(
        tester,
        fetchedAt,
        _FakeClock(fetchedAt.add(const Duration(seconds: 60))),
      );

      expect(find.text('Last synced 1m ago'), findsOneWidget);
    },
  );

  testWidgets('shows "Nm ago" for minutes', (tester) async {
    final fetchedAt = DateTime(2026, 1, 1, 12, 0, 0);
    await pumpChip(
      tester,
      fetchedAt,
      _FakeClock(fetchedAt.add(const Duration(minutes: 5))),
    );

    expect(find.text('Last synced 5m ago'), findsOneWidget);
  });

  testWidgets('shows "Nh ago" for hours', (tester) async {
    final fetchedAt = DateTime(2026, 1, 1, 12, 0, 0);
    await pumpChip(
      tester,
      fetchedAt,
      _FakeClock(fetchedAt.add(const Duration(hours: 2))),
    );

    expect(find.text('Last synced 2h ago'), findsOneWidget);
  });

  testWidgets('shows "Nd ago" for days', (tester) async {
    final fetchedAt = DateTime(2026, 1, 1, 12, 0, 0);
    await pumpChip(
      tester,
      fetchedAt,
      _FakeClock(fetchedAt.add(const Duration(days: 3))),
    );

    expect(find.text('Last synced 3d ago'), findsOneWidget);
  });

  testWidgets('defaults to the system clock when none is supplied', (
    tester,
  ) async {
    final fetchedAt = DateTime.now().subtract(const Duration(seconds: 1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StaleDataChip(fetchedAt: fetchedAt)),
      ),
    );

    expect(find.text('Last synced just now'), findsOneWidget);
  });
}
