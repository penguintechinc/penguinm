import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:penguin_app_shell/penguin_app_shell.dart';

void main() {
  test('BootstrapWarning.toString includes the step and error', () {
    final warning = BootstrapWarning('telemetry', StateError('boom'));
    expect(warning.toString(), 'BootstrapWarning(telemetry: Bad state: boom)');
    expect(warning.step, 'telemetry');
    expect(warning.error, isA<StateError>());
  });

  test('BootstrapResult carries its overrides, duration, and warnings', () {
    const overrides = <Override>[];
    final warnings = [BootstrapWarning('flags', 'nope')];
    final result = BootstrapResult(
      overrides: overrides,
      startupDuration: const Duration(milliseconds: 5),
      warnings: warnings,
    );
    expect(result.overrides, same(overrides));
    expect(result.startupDuration, const Duration(milliseconds: 5));
    expect(result.warnings, same(warnings));
  });
}
