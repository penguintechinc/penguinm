import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../pigeon/pipeline.g.dart';

/// The [GazerHostApi] the app talks to; overridden in tests with
/// `FakeGazerHostApi` so no real Pigeon channel is ever touched.
final gazerHostApiProvider = Provider<GazerHostApi>((ref) => GazerHostApi());

/// Enumerable video sources (M1: back/front camera only). M1 has no
/// hot-plug refresh — the list is read once per provider build; USB/UVC
/// device attach-and-refresh arrives in M2.
final videoDevicesProvider = FutureProvider.autoDispose<List<VideoDevice>>((
  ref,
) async {
  final host = ref.watch(gazerHostApiProvider);
  return host.listVideoDevices();
});

/// Enumerable audio sources (M1: mic + silence only). M1 has no hot-plug
/// refresh — the list is read once per provider build; USB/UVC audio
/// attach-and-refresh arrives in M2.
final audioDevicesProvider = FutureProvider.autoDispose<List<AudioDevice>>((
  ref,
) async {
  final host = ref.watch(gazerHostApiProvider);
  return host.listAudioDevices();
});
