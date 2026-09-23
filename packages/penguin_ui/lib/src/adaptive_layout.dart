import 'package:flutter/material.dart';
import 'form_factor.dart';

/// Adapts layout based on form factor, selecting the appropriate builder.
///
/// Uses FormFactor.of(context) to determine the current form factor, then
/// calls the matching builder. If expanded builder is null, falls back to tablet.
class AdaptiveLayout extends StatelessWidget {
  /// Creates an adaptive layout with phone, tablet, and optional expanded builders.
  const AdaptiveLayout({
    super.key,
    required this.phone,
    required this.tablet,
    this.expanded,
  });

  /// Builder for phone form factor (< 600 logical pixels).
  final WidgetBuilder phone;

  /// Builder for tablet form factor (600-899 logical pixels).
  final WidgetBuilder tablet;

  /// Optional builder for expanded form factor (≥ 900 logical pixels).
  /// If null, tablet builder is used instead.
  final WidgetBuilder? expanded;

  @override
  Widget build(BuildContext context) {
    final formFactor = FormFactor.of(context);
    final builder = switch (formFactor) {
      FormFactor.phone => phone,
      FormFactor.tablet => tablet,
      FormFactor.expanded => expanded ?? tablet,
    };
    return builder(context);
  }
}
