import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'client.dart';

/// Riverpod provider for [PenguinApiClient], initially unimplemented (must be
/// overridden at bootstrap time with a real instance). Apps override this
/// provider in their main manifest or shell bootstrap.
final apiClientProvider = Provider<PenguinApiClient>(
  (_) => throw UnimplementedError(
    'apiClientProvider must be overridden with a real PenguinApiClient instance',
  ),
);
