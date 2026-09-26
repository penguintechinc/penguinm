import 'package:penguin_api/penguin_api.dart';
import 'package:penguin_core/penguin_core.dart';

import '../domain/user.dart';

/// Fetches the signed-in user's profile from the backend — the only place
/// in the `profile` feature that calls [PenguinApiClient], per the app's
/// `data/` layer convention. Requires connectivity: unlike the springboard
/// (static, bundled content), a profile is always fetched fresh, never
/// served from an offline cache (see `README.md`'s offline table).
class ProfileRepository {
  /// Creates a repository fetching from [profilePath] (defaults to the
  /// transitional password-auth path, `/api/v1/auth/profile`) via [api].
  const ProfileRepository({
    required this.api,
    this.profilePath = '/api/v1/auth/profile',
  });

  /// The shared API client this repository calls through.
  final PenguinApiClient api;

  /// The backend path serving the current user's profile.
  final String profilePath;

  /// Fetches the current user's profile; failures (network, auth, decode)
  /// surface as a typed [Failure] rather than throwing.
  Future<Result<User>> fetchProfile() {
    return api.get<User>(
      profilePath,
      decode: (json) {
        if (json is! Map<String, Object?>) {
          throw const FormatException('Expected a JSON object');
        }
        return User.fromJson(json);
      },
    );
  }
}
