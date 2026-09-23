import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_ui/penguin_ui.dart';

void main() {
  group('LoadingView', () {
    testWidgets('renders a centered progress indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingView())),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Center), findsOneWidget);
    });
  });

  group('EmptyView', () {
    testWidgets('renders centered message', (tester) async {
      const message = 'No items found';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmptyView(message: message)),
        ),
      );

      expect(find.text(message), findsOneWidget);
      expect(find.byType(Center), findsOneWidget);
    });
  });

  group('ErrorView', () {
    testWidgets('renders error icon and message for NetworkFailure', (
      tester,
    ) async {
      const failure = NetworkFailure('Network error');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorView(failure: failure)),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(
        find.text('Network error. Check your connection and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('renders error message for AuthFailure', (tester) async {
      const failure = AuthFailure(401, 'Unauthorized');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorView(failure: failure)),
        ),
      );

      expect(
        find.text('Authentication failed. Please sign in again.'),
        findsOneWidget,
      );
    });

    testWidgets('renders error message for StorageFailure', (tester) async {
      const failure = StorageFailure('Storage failed');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorView(failure: failure)),
        ),
      );

      expect(
        find.text('Storage error. Please try again later.'),
        findsOneWidget,
      );
    });

    testWidgets('renders error message for ServerFailure', (tester) async {
      const failure = ServerFailure(500, 'Server error');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorView(failure: failure)),
        ),
      );

      expect(
        find.text('Server error. Please try again later.'),
        findsOneWidget,
      );
    });

    testWidgets('renders retry button and calls onRetry when tapped', (
      tester,
    ) async {
      var retryCount = 0;
      const failure = NetworkFailure('Error');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(failure: failure, onRetry: () => retryCount++),
          ),
        ),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(retryCount, 1);
    });

    testWidgets('does not render retry button when onRetry is null', (
      tester,
    ) async {
      const failure = NetworkFailure('Error');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorView(failure: failure)),
        ),
      );

      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('renders error message for ValidationFailure', (tester) async {
      const failure = ValidationFailure('email', 'Invalid format');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ErrorView(failure: failure)),
        ),
      );

      expect(
        find.text('Invalid email. Please check and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('renders generic message for UnknownFailure', (tester) async {
      final failure = UnknownFailure(Exception('Unexpected'), StackTrace.empty);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ErrorView(failure: failure)),
        ),
      );

      expect(
        find.text('An unexpected error occurred. Please try again.'),
        findsOneWidget,
      );
    });
  });

  group('AdaptiveLayout', () {
    testWidgets('calls phone builder for phone form factor', (tester) async {
      tester.view.physicalSize = const Size(599, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveLayout(
              phone: (_) => const Text('Phone'),
              tablet: (_) => const Text('Tablet'),
              expanded: (_) => const Text('Expanded'),
            ),
          ),
        ),
      );

      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Tablet'), findsNothing);
      expect(find.text('Expanded'), findsNothing);
    });

    testWidgets('calls tablet builder for tablet form factor', (tester) async {
      tester.view.physicalSize = const Size(700, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveLayout(
              phone: (_) => const Text('Phone'),
              tablet: (_) => const Text('Tablet'),
              expanded: (_) => const Text('Expanded'),
            ),
          ),
        ),
      );

      expect(find.text('Phone'), findsNothing);
      expect(find.text('Tablet'), findsOneWidget);
      expect(find.text('Expanded'), findsNothing);
    });

    testWidgets('calls expanded builder for expanded form factor', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveLayout(
              phone: (_) => const Text('Phone'),
              tablet: (_) => const Text('Tablet'),
              expanded: (_) => const Text('Expanded'),
            ),
          ),
        ),
      );

      expect(find.text('Phone'), findsNothing);
      expect(find.text('Tablet'), findsNothing);
      expect(find.text('Expanded'), findsOneWidget);
    });

    testWidgets('falls back to tablet when expanded is null', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdaptiveLayout(
              phone: (_) => const Text('Phone'),
              tablet: (_) => const Text('Tablet'),
            ),
          ),
        ),
      );

      expect(find.text('Phone'), findsNothing);
      expect(find.text('Tablet'), findsOneWidget);
    });
  });
}
