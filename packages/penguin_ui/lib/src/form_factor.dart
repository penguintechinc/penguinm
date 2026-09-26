import 'package:flutter/material.dart';

/// Device form factor based on logical pixel width.
///
/// Phone: < 600 logical pixels (typical mobile)
/// Tablet: 600-899 logical pixels (landscape phone or small tablet)
/// Expanded: ≥ 900 logical pixels (large tablet or desktop)
enum FormFactor {
  /// Phone form factor: < 600 logical pixels.
  phone,

  /// Tablet form factor: 600-899 logical pixels.
  tablet,

  /// Expanded form factor: ≥ 900 logical pixels.
  expanded;

  /// Determines the form factor for the given build context.
  ///
  /// Uses [MediaQuery.of] to get the logical width and clasifies it as
  /// phone (< 600), tablet (600-899), or expanded (≥ 900).
  static FormFactor of(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) {
      return FormFactor.phone;
    } else if (width < 900) {
      return FormFactor.tablet;
    } else {
      return FormFactor.expanded;
    }
  }
}
