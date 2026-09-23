import 'package:flutter/material.dart';
import 'package:penguin_core/penguin_core.dart';

/// An error view displaying a failure with an optional retry button.
///
/// Shows a user-safe error message appropriate to the failure type,
/// and calls [onRetry] when the user taps the retry button (if provided).
class ErrorView extends StatelessWidget {
  /// Creates an error view displaying [failure] with optional [onRetry] callback.
  const ErrorView({super.key, required this.failure, this.onRetry});

  /// The failure to display.
  final Failure failure;

  /// Callback invoked when the user taps the retry button, if provided.
  final VoidCallback? onRetry;

  /// Returns a user-safe message for the given failure type.
  static String messageForFailure(Failure failure) {
    return switch (failure) {
      NetworkFailure() => 'Network error. Check your connection and try again.',
      AuthFailure() => 'Authentication failed. Please sign in again.',
      ValidationFailure(:final field) =>
        'Invalid $field. Please check and try again.',
      StorageFailure() => 'Storage error. Please try again later.',
      ServerFailure() => 'Server error. Please try again later.',
      UnknownFailure() => 'An unexpected error occurred. Please try again.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              messageForFailure(failure),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
