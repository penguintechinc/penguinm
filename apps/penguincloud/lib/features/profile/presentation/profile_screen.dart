import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penguin_auth/penguin_auth.dart';
import 'package:penguin_core/penguin_core.dart';
import 'package:penguin_ui/penguin_ui.dart';

import '../domain/user.dart';
import 'profile_providers.dart';

/// PenguinCloud's profile screen: account details and sign-out. Ported
/// from the legacy mobile app's `ProfileScreen` — a scrollable column on
/// phone, a static account-tabs sidebar beside the content on
/// tablet/expanded. Requires connectivity (see `README.md`'s offline
/// table): the profile is always fetched fresh via [profileProvider],
/// never served from an offline cache.
class ProfileScreen extends ConsumerWidget {
  /// Creates the profile screen.
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdaptiveLayout(
      phone: (context) => const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: _ProfileContent(),
        ),
      ),
      tablet: (context) => const SafeArea(child: _TabletProfile()),
    );
  }
}

/// Tablet layout for the profile feature: a two-pane [SafeArea] view
/// rendering [_ProfileContent] beside the springboard chrome.
class _TabletProfile extends StatelessWidget {
  const _TabletProfile();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: Container(
            color: colors.surfaceContainerHigh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                _ProfileHeader(),
                Divider(),
                ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Account'),
                  selected: true,
                ),
                ListTile(
                  leading: Icon(Icons.security),
                  title: Text('Security'),
                ),
                ListTile(
                  leading: Icon(Icons.notifications),
                  title: Text('Notifications'),
                ),
              ],
            ),
          ),
        ),
        const Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: _ProfileContent(),
          ),
        ),
      ],
    );
  }
}

/// Watches [profileProvider] and renders a [LoadingView], [ErrorView]
/// (with retry), or the resolved [User] via [builder] — the one place
/// that unwraps the `AsyncValue<Result<User>>` two-layer state so both
/// `_ProfileHeader` and `_ProfileContent` render the same user
/// consistently.
class _ProfileState extends ConsumerWidget {
  const _ProfileState({required this.builder});

  final Widget Function(BuildContext context, User user) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profileProvider);
    return async.when(
      loading: () => const LoadingView(),
      error: (error, stackTrace) => ErrorView(
        failure: UnknownFailure(error, stackTrace),
        onRetry: () => ref.invalidate(profileProvider),
      ),
      data: (result) => result.fold(
        (user) => builder(context, user),
        (failure) => ErrorView(
          failure: failure,
          onRetry: () => ref.invalidate(profileProvider),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _ProfileState(
      builder: (context, user) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: colors.primary,
              child: Text(
                _avatarInitial(user.name ?? user.email),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colors.onPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user.name ?? 'Unknown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user.email,
              style: TextStyle(fontSize: 14, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// The profile body shared by the phone and tablet layouts: renders the
/// signed-in user's avatar, name, and email from the auth session.
class _ProfileContent extends ConsumerWidget {
  const _ProfileContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return _ProfileState(
      builder: (context, user) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProfileHeader(),
          const SizedBox(height: 24),
          _buildSection(colors, 'Account Information', [
            _buildInfoTile(
              context,
              icon: Icons.email,
              label: 'Email',
              value: user.email,
            ),
            _buildInfoTile(
              context,
              icon: Icons.badge,
              label: 'Roles',
              value: user.roles.isEmpty ? 'None' : user.roles.join(', '),
            ),
            _buildInfoTile(
              context,
              icon: Icons.fingerprint,
              label: 'User ID',
              value: user.id,
            ),
          ]),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  ref.read(authControllerProvider.notifier).logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.error,
                foregroundColor: colors.onError,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(ColorScheme colors, String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ...tiles,
      ],
    );
  }

  Widget _buildInfoTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: colors.onSurfaceVariant),
      title: Text(
        label,
        style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
      ),
      subtitle: Text(
        value,
        style: TextStyle(fontSize: 16, color: colors.onSurface),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// First character of [label] upper-cased for an avatar badge, or `?`
/// when [label] is empty or whitespace (guards against a RangeError on an
/// empty display name/email).
String _avatarInitial(String label) {
  final trimmed = label.trim();
  return trimmed.isEmpty ? '?' : trimmed.substring(0, 1).toUpperCase();
}
