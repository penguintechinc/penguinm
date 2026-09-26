import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_offline/src/connectivity_status.dart';

void main() {
  test('has exactly online, offline, unknown values', () {
    expect(
      ConnectivityStatus.values,
      containsAll(<ConnectivityStatus>[
        ConnectivityStatus.online,
        ConnectivityStatus.offline,
        ConnectivityStatus.unknown,
      ]),
    );
    expect(ConnectivityStatus.values, hasLength(3));
  });
}
