import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penguin_auth/penguin_auth.dart';

import 'springboard_grid.dart';

/// Best-effort display name for the welcome header: the JWT's `name`
/// claim, then `email`, then the subject id, then a generic fallback —
/// mirrors the legacy app's `authProvider.currentUser?.name ?? email ??
/// 'User'` without requiring a dedicated profile fetch just to greet the
/// user.
String _greetingName(WidgetRef ref) {
  final state = ref.watch(authControllerProvider);
  if (state is! Authenticated) return 'User';
  final claims = state.session.claims;
  final name = claims.raw['name'];
  if (name is String && name.isNotEmpty) return name;
  final email = claims.raw['email'];
  if (email is String && email.isNotEmpty) return email;
  return claims.sub ?? 'User';
}

/// PenguinCloud's home screen: a welcome header above the role-filtered
/// [SpringboardGrid]. Ported from the legacy mobile app's
/// `SpringboardHomePage`.
class SpringboardScreen extends ConsumerWidget {
  /// Creates the springboard home screen.
  const SpringboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final name = _greetingName(ref);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              'Welcome, $name',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Text(
              'Your springboard',
              style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
            ),
          ),
          const Expanded(child: SpringboardGrid()),
        ],
      ),
    );
  }
}
