/// Outcome summary of one [SyncQueue.drain] call.
class SyncReport {
  /// Creates a report; all counts default to zero (an empty drain).
  const SyncReport({this.sent = 0, this.failed = 0, this.deadLettered = 0});

  /// Writes that were successfully sent and removed from the queue.
  final int sent;

  /// Writes still queued after this drain because a `401`/`403` response
  /// stopped draining early (the auth layer is expected to recover the
  /// session before the next drain).
  final int failed;

  /// Writes that received a non-retriable error and were removed from the
  /// queue, surfaced via [SyncQueue.deadLetters].
  final int deadLettered;

  /// Total writes this drain call attempted.
  int get total => sent + failed + deadLettered;
}
