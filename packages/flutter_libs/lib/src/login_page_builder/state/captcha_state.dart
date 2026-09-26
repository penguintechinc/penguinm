import 'package:flutter/foundation.dart';

/// State management for CAPTCHA display logic.
///
/// Tracks failed login attempts and determines when to show the CAPTCHA widget.
/// Replaces the React useCaptcha hook.
class CaptchaNotifier extends ChangeNotifier {
  /// Creates a [CaptchaNotifier] with configurable attempt threshold and timeout.
  CaptchaNotifier({this.threshold = 3, this.resetTimeoutMs = 900000});

  /// Number of failed attempts before CAPTCHA is shown (default 3).
  final int threshold;

  /// Timeout in milliseconds to reset the attempt counter (default 15 min).
  final int resetTimeoutMs;

  int _failedAttempts = 0;
  String? _captchaToken;
  DateTime? _firstFailure;

  /// Number of consecutive failed login attempts.
  int get failedAttempts => _failedAttempts;

  /// Whether the CAPTCHA should be displayed.
  bool get showCaptcha => _failedAttempts >= threshold;

  /// Whether the CAPTCHA has been verified.
  bool get isVerified => _captchaToken != null;

  /// The CAPTCHA verification token.
  String? get captchaToken => _captchaToken;

  /// Record a failed login attempt.
  void recordFailure() {
    _firstFailure ??= DateTime.now();

    // Reset if timeout elapsed
    final elapsed = DateTime.now().difference(_firstFailure!).inMilliseconds;
    if (elapsed > resetTimeoutMs) {
      _failedAttempts = 0;
      _firstFailure = DateTime.now();
    }

    _failedAttempts++;
    _captchaToken = null;
    notifyListeners();
  }

  /// Set the CAPTCHA verification token.
  void setCaptchaToken(String token) {
    _captchaToken = token;
    notifyListeners();
  }

  /// Reset after successful login.
  void reset() {
    _failedAttempts = 0;
    _captchaToken = null;
    _firstFailure = null;
    notifyListeners();
  }
}
