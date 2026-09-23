import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_flags/penguin_flags.dart';

/// Scripted [FlagSource] fake: [fetch] returns a settable [Result] instead
/// of calling PostHog, recording every `distinctId`/`properties` pair it
/// was called with.
class FakeFlagSource implements FlagSource {
  /// Creates a fake flag source that returns [initialResult] (defaults to
  /// an empty, successful flag map) until [setResult] changes it.
  FakeFlagSource({Result<Map<String, Object?>>? initialResult})
    : _result = initialResult ?? const Result.ok(<String, Object?>{});

  Result<Map<String, Object?>> _result;

  /// Every `distinctId` passed to [fetch] so far, in order.
  final List<String> distinctIds = <String>[];

  /// Every `properties` map passed to [fetch] so far, in order.
  final List<Map<String, String>> properties = <Map<String, String>>[];

  /// Changes the [Result] the next [fetch] call returns.
  void setResult(Result<Map<String, Object?>> result) {
    _result = result;
  }

  @override
  Future<Result<Map<String, Object?>>> fetch({
    required String distinctId,
    Map<String, String> properties = const <String, String>{},
  }) async {
    distinctIds.add(distinctId);
    this.properties.add(properties);
    return _result;
  }
}
