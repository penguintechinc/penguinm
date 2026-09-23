import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_providers.dart';

/// Home screen for {{display_name}}.
class HomeScreen extends ConsumerWidget {
  /// Creates a home screen.
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greetings = ref.watch(greetingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: ListView.builder(
          itemCount: greetings.length,
          itemBuilder: (context, index) {
            final greeting = greetings[index];
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(greeting.text),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
