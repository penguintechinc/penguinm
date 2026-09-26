import 'package:{{name}}/features/home/domain/greeting.dart';

/// Fixture greetings for testing — mirrors `greetingsProvider`'s literal
/// values so widget tests can assert on shared data instead of duplicating
/// the strings.
const greetings = [
  Greeting(text: 'Welcome to {{display_name}}'),
  Greeting(text: 'Tap to interact'),
  Greeting(text: 'All features use feature flags'),
];
