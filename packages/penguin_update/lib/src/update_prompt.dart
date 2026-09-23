import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penguin_api/penguin_api.dart';
import 'package:url_launcher/url_launcher.dart';

import 'store_url.dart';
import 'update_status.dart';

/// Prompts the user to update the app when a new version is available.
///
/// Displays a dismissible banner when an update is available or a
/// non-dismissible dialog when an update is required. No UI is shown
/// when the app is up to date or when the check fails.
class UpdatePrompt extends ConsumerWidget {
  /// Creates an update prompt with the given status and app ID.
  const UpdatePrompt({
    required this.applicationId,
    required this.status,
    super.key,
  });

  /// The application ID (e.g., 'io.penguintech.myapp').
  final String applicationId;

  /// The status from the update check.
  final UpdateStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (status) {
      UpToDate() => const SizedBox.shrink(),
      Unknown() => const SizedBox.shrink(),
      UpdateAvailable(info: final info) => _buildAvailableBanner(context, info),
      UpdateRequired(info: final info) => _buildRequiredDialog(context, info),
    };
  }

  /// Builds a dismissible banner for available updates.
  Widget _buildAvailableBanner(
    BuildContext context,
    ClientVersionInfo versionInfo,
  ) {
    return MaterialBanner(
      content: const Text('A new version is available'),
      actions: [
        TextButton(
          onPressed: () => _launchStore(versionInfo),
          child: const Text('Update'),
        ),
        TextButton(
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
          },
          child: const Text('Later'),
        ),
      ],
    );
  }

  /// Builds a non-dismissible dialog for required updates.
  Widget _buildRequiredDialog(
    BuildContext context,
    ClientVersionInfo versionInfo,
  ) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Update Required'),
        content: const Text(
          'This version of the app is no longer supported. '
          'Please update to continue using the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => _launchStore(versionInfo),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  /// Launches the app store with the update URL.
  Future<void> _launchStore(ClientVersionInfo versionInfo) async {
    final url = storeUrlFor(applicationId, versionInfo);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Silently fail if launch fails
    }
  }
}
