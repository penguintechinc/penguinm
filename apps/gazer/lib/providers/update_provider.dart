import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../config/constants.dart';
import '../models/update_info.dart';
import '../services/update_checker.dart';

/// The [UpdateChecker] the app uses; overridden in tests with one wired to
/// a mocked `http.Client`.
///
/// [UpdateChecker.releasesUrl] is wired explicitly to [kGithubReleasesUrl]
/// rather than the constructor's own literal default, so the single
/// source of truth in `config/constants.dart` is what production actually
/// polls.
final updateCheckerProvider = FutureProvider<UpdateChecker>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return UpdateChecker(
    client: http.Client(),
    currentVersion: packageInfo.version,
    releasesUrl: kGithubReleasesUrl,
  );
});

/// Startup, non-blocking update check surfaced in the status panel.
final updateInfoProvider = FutureProvider.autoDispose<UpdateInfo?>((ref) async {
  final checker = await ref.watch(updateCheckerProvider.future);
  return checker.check();
});
