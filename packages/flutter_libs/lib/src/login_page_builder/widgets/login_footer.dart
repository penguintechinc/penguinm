import 'package:flutter/material.dart';
import '../../theme/elder_colors.dart';

/// Footer section for the login page with optional links.
class LoginFooter extends StatelessWidget {
  /// Creates a [LoginFooter] with optional policy links and copyright text.
  const LoginFooter({
    super.key,
    this.githubRepo,
    this.privacyPolicyUrl,
    this.termsUrl,
    this.copyrightText,
    this.onLinkTap,
    this.textColor = ElderColors.slate500,
    this.linkColor = ElderColors.amber400,
  });

  /// Optional GitHub repository URL.
  final String? githubRepo;

  /// Optional URL to the privacy policy.
  final String? privacyPolicyUrl;

  /// Optional URL to the terms of service.
  final String? termsUrl;

  /// Optional copyright notice text.
  final String? copyrightText;

  /// Custom handler for link taps instead of launching URLs.
  final void Function(String url)? onLinkTap;

  /// Color for footer text.
  final Color textColor;

  /// Color for footer links.
  final Color linkColor;

  @override
  Widget build(BuildContext context) {
    final links = <Widget>[];

    if (githubRepo != null) {
      links.add(_buildLink('GitHub', githubRepo!));
    }
    if (privacyPolicyUrl != null) {
      links.add(_buildLink('Privacy Policy', privacyPolicyUrl!));
    }
    if (termsUrl != null) {
      links.add(_buildLink('Terms of Service', termsUrl!));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          if (links.isNotEmpty)
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: links,
            ),
          if (copyrightText != null) ...[
            const SizedBox(height: 8),
            Text(
              copyrightText!,
              style: TextStyle(color: textColor, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLink(String label, String url) {
    return GestureDetector(
      onTap: () => onLinkTap?.call(url),
      child: Text(
        label,
        style: TextStyle(
          color: linkColor,
          fontSize: 13,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
      ),
    );
  }
}
