import 'package:penguin_update/penguin_update.dart';

/// Scripted stand-in for `penguin_update`'s [UpdateChecker].
///
/// `UpdateChecker`'s constructor requires a `PenguinApiClient`/
/// `PenguinLogger`, but its *interface* (as seen from another library) is
/// just its one public member, `check({required String currentVersion})`
/// — private fields and helpers (`_api`, `_log`, `_checkVersions`) impose
/// nothing on an `implements` from outside `penguin_update`. So
/// [FakeUpdateChecker] genuinely `implements` it and is a real substitute
/// anywhere an `UpdateChecker` is expected, e.g.
/// `updateCheckerProvider.overrideWithValue(FakeUpdateChecker())` — not a
/// duck-typed stand-in usable only where callers happen to consume
/// [UpdateStatus] directly.
class FakeUpdateChecker implements UpdateChecker {
  /// Creates a fake checker returning [defaultStatus] (defaults to
  /// [UpdateStatus.upToDate]) whenever the scripted queue is empty.
  FakeUpdateChecker([UpdateStatus? defaultStatus])
    : _default = defaultStatus ?? const UpdateStatus.upToDate();

  final UpdateStatus _default;
  final List<UpdateStatus> _queue = <UpdateStatus>[];

  /// Every `currentVersion` passed to [check] so far, in order.
  final List<String> checkedVersions = <String>[];

  /// Appends [status] to the queue [check] draws from, first in first out.
  void queue(UpdateStatus status) {
    _queue.add(status);
  }

  @override
  Future<UpdateStatus> check({required String currentVersion}) async {
    checkedVersions.add(currentVersion);
    if (_queue.isNotEmpty) return _queue.removeAt(0);
    return _default;
  }
}
