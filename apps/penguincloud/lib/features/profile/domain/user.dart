/// A PenguinCloud user profile, decoded from `GET /api/v1/auth/profile`.
/// Ported 1:1 from the legacy mobile app's `User` model — plain data plus
/// the same role-check helpers, no Flutter dependency.
class User {
  /// Creates a user profile.
  const User({
    required this.id,
    required this.email,
    this.name,
    this.roles = const [],
  });

  /// Stable user identifier.
  final String id;

  /// The user's email address.
  final String email;

  /// The user's display name, when the server provides one.
  final String? name;

  /// Roles assigned to this user.
  final List<String> roles;

  /// Decodes a [User] from the profile endpoint's JSON body.
  factory User.fromJson(Map<String, Object?> json) => User(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String?,
    roles:
        (json['roles'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        const [],
  );

  /// Encodes this user back to a JSON-safe map.
  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    if (name != null) 'name': name,
    'roles': roles,
  };

  /// True when this user has been granted [role].
  bool hasRole(String role) => roles.contains(role);

  /// True when this user holds the `admin` role.
  bool get isAdmin => hasRole('admin');
}
