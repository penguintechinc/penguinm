import 'package:go_router/go_router.dart';
import 'auth_state.dart';

/// Routes unauthenticated users to login and authenticated users away from it.
/// For use with [GoRouter.redirect]. Returns the redirect path or null to
/// proceed normally.
///
/// - If unauthenticated/expired and accessing a protected route → redirect to [loginPath]
/// - If authenticated and accessing login → redirect to [homePath]
/// - Otherwise, allow the navigation to proceed (null)
String? authRedirect(
  AuthState state,
  GoRouterState routeState, {
  required String loginPath,
  required String homePath,
}) {
  final isAuthenticated = state is Authenticated;
  final isLoggingIn = routeState.uri.path == loginPath;

  if (!isAuthenticated && !isLoggingIn) {
    // Unauthenticated and not already on login → go to login.
    return loginPath;
  }

  if (isAuthenticated && isLoggingIn) {
    // Authenticated and on login → go to home.
    return homePath;
  }

  return null; // Proceed normally.
}
