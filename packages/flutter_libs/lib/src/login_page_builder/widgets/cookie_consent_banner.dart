import 'package:flutter/material.dart';
import '../../theme/elder_colors.dart';

/// GDPR cookie consent banner displayed at the bottom of the screen.
///
/// Offers "Accept All", "Essential Only", and optional "Preferences" buttons.
class CookieConsentBanner extends StatelessWidget {
  /// Creates a [CookieConsentBanner] with consent callbacks and policy URLs.
  const CookieConsentBanner({
    super.key,
    required this.onAcceptAll,
    required this.onAcceptEssential,
    this.onShowPreferences,
    this.consentText,
    this.privacyPolicyUrl,
    this.cookiePolicyUrl,
    this.showPreferences = true,
    this.onLinkTap,
  });

  /// Called when the user accepts all cookies.
  final VoidCallback onAcceptAll;

  /// Called when the user accepts only essential cookies.
  final VoidCallback onAcceptEssential;

  /// Optional callback for showing detailed preferences.
  final VoidCallback? onShowPreferences;

  /// Custom consent text (default provides standard GDPR message).
  final String? consentText;

  /// URL to the privacy policy.
  final String? privacyPolicyUrl;

  /// URL to the cookie policy.
  final String? cookiePolicyUrl;

  /// Whether to show the "Preferences" button.
  final bool showPreferences;

  /// Custom handler for policy link taps instead of launching URLs.
  final void Function(String url)? onLinkTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: ElderColors.slate900,
        border: Border(top: BorderSide(color: ElderColors.slate700)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Consent text
          Text(
            consentText ??
                'We use cookies to enhance your experience. '
                    'By continuing, you agree to our use of cookies.',
            style: const TextStyle(color: ElderColors.slate300, fontSize: 13),
          ),

          // Links
          if (privacyPolicyUrl != null || cookiePolicyUrl != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (privacyPolicyUrl != null)
                  GestureDetector(
                    onTap: () => onLinkTap?.call(privacyPolicyUrl!),
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        color: ElderColors.amber400,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: ElderColors.amber400,
                      ),
                    ),
                  ),
                if (privacyPolicyUrl != null && cookiePolicyUrl != null)
                  const Text(
                    '  •  ',
                    style: TextStyle(color: ElderColors.slate500),
                  ),
                if (cookiePolicyUrl != null)
                  GestureDetector(
                    onTap: () => onLinkTap?.call(cookiePolicyUrl!),
                    child: const Text(
                      'Cookie Policy',
                      style: TextStyle(
                        color: ElderColors.amber400,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                        decorationColor: ElderColors.amber400,
                      ),
                    ),
                  ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: onAcceptAll,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ElderColors.amber500,
                  foregroundColor: ElderColors.slate900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: const Text('Accept All'),
              ),
              OutlinedButton(
                onPressed: onAcceptEssential,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ElderColors.slate300,
                  side: const BorderSide(color: ElderColors.slate600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                child: const Text('Essential Only'),
              ),
              if (showPreferences && onShowPreferences != null)
                TextButton(
                  onPressed: onShowPreferences,
                  style: TextButton.styleFrom(
                    foregroundColor: ElderColors.slate400,
                  ),
                  child: const Text('Preferences'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
