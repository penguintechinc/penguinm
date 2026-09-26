import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_offline/src/connectivity_status.dart';
import 'package:penguin_offline/src/providers.dart';
import 'package:penguin_offline/src/widgets/connectivity_banner.dart';

void main() {
  Future<void> pumpWithStatus(
    WidgetTester tester,
    Stream<ConnectivityStatus> stream,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [connectivityProvider.overrideWith((ref) => stream)],
        child: const MaterialApp(home: Scaffold(body: ConnectivityBanner())),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders nothing while online', (tester) async {
    await pumpWithStatus(tester, Stream.value(ConnectivityStatus.online));
    await tester.pump();

    expect(find.byIcon(Icons.cloud_off), findsNothing);
    expect(find.textContaining('Offline'), findsNothing);
  });

  testWidgets('renders nothing before the first status arrives', (
    tester,
  ) async {
    await pumpWithStatus(tester, const Stream<ConnectivityStatus>.empty());

    expect(find.byIcon(Icons.cloud_off), findsNothing);
  });

  testWidgets('shows the offline message when offline', (tester) async {
    await pumpWithStatus(tester, Stream.value(ConnectivityStatus.offline));
    await tester.pump();

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.textContaining('Offline'), findsOneWidget);
    expect(find.textContaining("sync when you're back online"), findsOneWidget);
  });

  testWidgets('hides again after transitioning back online', (tester) async {
    final controller = StreamController<ConnectivityStatus>();
    addTearDown(controller.close);
    await pumpWithStatus(tester, controller.stream);

    controller.add(ConnectivityStatus.offline);
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);

    controller.add(ConnectivityStatus.online);
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.cloud_off), findsNothing);
  });
}
