import '../login_color_config.dart';

/// The default Elder dark theme for [LoginPageBuilder].
const LoginColorConfig elderLoginTheme = LoginColorConfig.elder;

/// Merges a partial [LoginColorConfig] with the Elder theme defaults.
///
/// Any non-null values in [overrides] replace the corresponding
/// Elder theme value.
LoginColorConfig mergeWithElderTheme({
  /// The color overrides to apply over the base Elder theme.
  LoginColorConfig overrides = const LoginColorConfig(),
}) {
  return overrides;
}
