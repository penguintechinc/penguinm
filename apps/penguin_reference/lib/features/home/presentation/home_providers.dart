import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/greeting.dart';

/// Provides a list of greetings for the home screen.
final greetingsProvider = Provider<List<Greeting>>((ref) {
  return [
    const Greeting(text: 'Welcome to Penguin Reference'),
    const Greeting(text: 'Tap to interact'),
    const Greeting(text: 'All features use feature flags'),
  ];
});
