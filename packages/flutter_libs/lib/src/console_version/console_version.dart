import 'package:flutter/material.dart';
import 'version_info.dart';
import 'version_logger.dart';
import 'console_style_config.dart';

/// A widget that logs version info to the developer console on mount.
///
/// Renders nothing visible ([SizedBox.shrink]).
/// Place in the widget tree to trigger version logging once.
class ConsoleVersion extends StatefulWidget {
  /// Creates a [ConsoleVersion].
  const ConsoleVersion({
    super.key,
    required this.appName,
    required this.version,
    this.environment,
    this.metadata,
    this.styleConfig = ConsoleStyleConfig.elder,
  });

  /// Name of the application to display.
  final String appName;

  /// Version string to parse and log.
  final String version;

  /// Optional environment name (e.g., "dev", "beta", "prod").
  final String? environment;

  /// Optional metadata key-value pairs to include in the log.
  final Map<String, String>? metadata;

  /// Style configuration for console output.
  final ConsoleStyleConfig styleConfig;

  @override
  State<ConsoleVersion> createState() => _ConsoleVersionState();
}

class _ConsoleVersionState extends State<ConsoleVersion> {
  @override
  void initState() {
    super.initState();
    final info = parseVersion(widget.version);
    logVersionToConsole(
      widget.appName,
      info,
      environment: widget.environment,
      metadata: widget.metadata,
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
