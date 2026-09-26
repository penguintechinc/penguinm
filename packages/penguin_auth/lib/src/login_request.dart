import 'package:flutter_libs/flutter_libs.dart';

/// A login request: either interactive browser flow, password credentials,
/// or a result from the transitional LoginPageBuilder.
sealed class LoginRequest {
  const LoginRequest();

  /// Hosted OIDC/SAML browser flow (the default).
  const factory LoginRequest.interactive() = Interactive;

  /// In-app password form (transitional).
  const factory LoginRequest.password({
    required String email,
    required String password,
    String? mfaCode,
  }) = Password;

  /// Result from flutter_libs `LoginPageBuilder` (transitional).
  const factory LoginRequest.fromLoginResponse(LoginResponse response) =
      FromLoginResponse;
}

/// Interactive browser flow.
class Interactive extends LoginRequest {
  /// Creates an interactive login request.
  const Interactive();
}

/// In-app password credentials.
class Password extends LoginRequest {
  /// Creates a password login request.
  const Password({required this.email, required this.password, this.mfaCode});

  /// User email address.
  final String email;

  /// User password.
  final String password;

  /// Optional MFA code.
  final String? mfaCode;
}

/// Result from the in-app password form (transitional).
class FromLoginResponse extends LoginRequest {
  /// Creates a login request from a flutter_libs response.
  const FromLoginResponse(this.response);

  /// The response from LoginPageBuilder.
  final LoginResponse response;
}
