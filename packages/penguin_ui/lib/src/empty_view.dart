import 'package:flutter/material.dart';

/// An empty state view displaying a message when no data is available.
///
/// Shows a centered message to inform the user that no items match their
/// search or filter criteria, or that no data has been loaded yet.
class EmptyView extends StatelessWidget {
  /// Creates an empty view with the given [message].
  const EmptyView({super.key, required this.message});

  /// The message to display in the empty state.
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}
