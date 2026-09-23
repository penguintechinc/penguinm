import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_offline/src/sync_report.dart';

void main() {
  group('SyncReport', () {
    test('stores sent/failed/deadLettered counts', () {
      const report = SyncReport(sent: 5, failed: 2, deadLettered: 1);

      expect(report.sent, 5);
      expect(report.failed, 2);
      expect(report.deadLettered, 1);
    });

    test('defaults every count to zero', () {
      const report = SyncReport();
      expect(report.sent, 0);
      expect(report.failed, 0);
      expect(report.deadLettered, 0);
      expect(report.total, 0);
    });

    test('total sums sent + failed + deadLettered', () {
      const report = SyncReport(sent: 3, failed: 1, deadLettered: 2);
      expect(report.total, 6);
    });
  });
}
