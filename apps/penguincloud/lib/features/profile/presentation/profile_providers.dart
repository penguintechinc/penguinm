import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';

import '../data/profile_repository.dart';
import '../domain/user.dart';

/// The app's single [ProfileRepository] instance, built from the shared
/// [apiClientProvider].
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(api: ref.watch(apiClientProvider));
});

/// Fetches the current user's profile once per screen visit
/// (`autoDispose`, so it re-fetches on the next visit rather than caching
/// stale data forever); [ProfileScreen] folds the [Result] into
/// loading/error/content states. A refresh (pull-to-refresh, retry button)
/// is `ref.invalidate(profileProvider)`.
final profileProvider = FutureProvider.autoDispose<Result<User>>((ref) {
  return ref.watch(profileRepositoryProvider).fetchProfile();
});
