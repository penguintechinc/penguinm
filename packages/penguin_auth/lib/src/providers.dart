import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_backend.dart';
import 'auth_controller.dart';
import 'auth_state.dart';
import 'session_store.dart';

/// Provides the [AuthBackend] instance. Must be overridden by the app
/// (via [ProviderContainer] or `runPenguinApp` overrides) with the
/// concrete hosted or password backend — there is no safe default.
final authBackendProvider = Provider<AuthBackend>(
  (_) => throw UnimplementedError(
    'authBackendProvider must be overridden with a concrete AuthBackend',
  ),
);

/// Persists sessions in secure storage; overridden with a fake store in
/// tests so [AuthController] never touches the platform secure-storage
/// channel.
final sessionStoreProvider = Provider<SessionStore>((_) => SessionStore());

/// Creates the [Timer] backing [AuthController]'s scheduled refresh;
/// overridden with a fake factory in tests so refresh scheduling is
/// deterministic and never waits on real time.
final timerFactoryProvider = Provider<TimerFactory>((_) => Timer.new);

/// Provides the main [AuthController] managing login/logout and token
/// refresh. Implements `TokenProvider` so the API client can request
/// tokens.
final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
