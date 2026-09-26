/// A greeting message entity.
class Greeting {
  /// Creates a greeting with the given [text].
  const Greeting({required this.text});

  /// The greeting text.
  final String text;

  @override
  String toString() => 'Greeting(text: $text)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Greeting &&
          runtimeType == other.runtimeType &&
          text == other.text;

  @override
  int get hashCode => text.hashCode;
}
