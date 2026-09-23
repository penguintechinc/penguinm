import 'package:flutter/material.dart';

/// A simple loading view displaying a centered progress indicator.
///
/// Used to show that data is being fetched or processed.
class LoadingView extends StatelessWidget {
  /// Creates a loading view.
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
