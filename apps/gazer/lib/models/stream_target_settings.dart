import '../services/gazer_log.dart';

/// User-supplied RTMP/RTMPS destination: URL, optional stream key, and an
/// optional both-or-neither username/password pair.
///
/// Every field here is sensitive: [SecureSettingsRepository] stores it in
/// `flutter_secure_storage`, never `shared_preferences`, and it is never
/// logged. Validation and the key-append/dedupe logic live in
/// `TargetValidator`, not here.
///
/// Hand-written immutable value class (no code generation): const
/// constructor, value equality, `copyWith`, and manual JSON codec, plus
/// the redacting [toString] override below.
class StreamTargetSettings {
  /// Creates an immutable stream target settings snapshot.
  const StreamTargetSettings({
    required this.url,
    this.streamKey,
    this.username,
    this.password,
  });

  /// Deserializes a [StreamTargetSettings] from JSON (round-trip tests only).
  factory StreamTargetSettings.fromJson(Map<String, dynamic> json) =>
      StreamTargetSettings(
        url: json['url'] as String,
        streamKey: json['streamKey'] as String?,
        username: json['username'] as String?,
        password: json['password'] as String?,
      );

  /// Empty target: blank URL, no key, no credentials — the pre-setup state.
  factory StreamTargetSettings.empty() => const StreamTargetSettings(url: '');

  /// RTMP/RTMPS destination URL.
  final String url;

  /// Optional stream key appended to [url] (or supplied separately).
  final String? streamKey;

  /// Optional basic-auth username; both-or-neither with [password].
  final String? username;

  /// Optional basic-auth password; both-or-neither with [username].
  final String? password;

  /// Serializes this instance to JSON (round-trip tests only).
  Map<String, dynamic> toJson() => <String, dynamic>{
    'url': url,
    'streamKey': streamKey,
    'username': username,
    'password': password,
  };

  /// Returns a copy with the given fields replaced.
  ///
  /// Nullable fields ([streamKey]/[username]/[password]) use an explicit
  /// `Object?` sentinel default so a caller can pass `null` to actually
  /// clear a field rather than leaving it unchanged.
  StreamTargetSettings copyWith({
    String? url,
    Object? streamKey = _unset,
    Object? username = _unset,
    Object? password = _unset,
  }) => StreamTargetSettings(
    url: url ?? this.url,
    streamKey: identical(streamKey, _unset)
        ? this.streamKey
        : streamKey as String?,
    username: identical(username, _unset) ? this.username : username as String?,
    password: identical(password, _unset) ? this.password : password as String?,
  );

  static const Object _unset = Object();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StreamTargetSettings &&
          other.url == url &&
          other.streamKey == streamKey &&
          other.username == username &&
          other.password == password);

  @override
  int get hashCode => Object.hash(url, streamKey, username, password);

  /// Redacted string form (R22): this class is logged and nested inside
  /// [GazerSettings]'s own toString, so the default field dump (which would
  /// print every field in plaintext) is overridden here. [url] keeps its
  /// scheme/host/earlier path segments but masks its **last** path
  /// segment, and drops userinfo/query/fragment; [username] and [password]
  /// print as `<redacted>`; [streamKey] prints masked with only its last 4
  /// characters visible, enough to eyeball "is this the key I expect"
  /// without exposing it.
  @override
  String toString() {
    return 'StreamTargetSettings(url: $_redactedUrl, streamKey: $_redactedStreamKey, '
        'username: ${_redactCredential(username)}, password: ${_redactCredential(password)})';
  }

  /// The URL with its last path segment masked.
  ///
  /// Previously this returned `host + path` in full, which prints the
  /// stream key verbatim whenever the user pastes a complete
  /// `rtmp://host/live/KEY` URL -- a form the spec explicitly supports.
  /// A redaction helper that prints the secret is a hole in exactly the
  /// control meant to be defence-in-depth, so the masking is now shared
  /// with [GazerLog.maskUrlLastSegment].
  String get _redactedUrl {
    if (url.isEmpty) return '';
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return '<redacted>';
    return GazerLog.maskUrlLastSegment(url);
  }

  String get _redactedStreamKey {
    final key = streamKey;
    if (key == null) return 'null';
    if (key.length <= 4) return '****';
    return '****${key.substring(key.length - 4)}';
  }

  /// `null` stays `null` (absence isn't a secret); any non-null value,
  /// however short, redacts fully rather than partially mask it.
  String _redactCredential(String? value) =>
      value == null ? 'null' : '<redacted>';
}
