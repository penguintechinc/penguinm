# Native Modules — When and How

Native code in Dart (Kotlin/Swift) is the exception, not the rule. Flutter handles 95% of use cases.

## When Native Code IS Justified

| Reason | Example |
|---|---|
| Flutter has **zero packages** for the feature | Custom RTMP encoder, UVC camera direct control |
| Packages exist but are **unmaintained or incomplete** | Outdated Bluetooth plugin with no passive scanning |
| **Performance-critical** low-level operations | Real-time audio processing, custom camera pipeline |
| **Platform-specific APIs** with no Flutter equivalent | HealthKit for iOS, Health Connect Android variants, advanced NFC modes |
| **Security-sensitive operations** requiring direct platform APIs | Hardware keystore access, biometric unlock, secure credential storage |

## When Native Code is NOT Justified

| Reason | What to do instead |
|---|---|
| "It would be faster in native" | Measure first; Flutter is surprisingly fast. Use profiler. |
| Developer prefers native | Use Flutter anyway. The codebase is unified for a reason. |
| A plugin exists but has bugs | Fix the plugin or file an issue. Fork if necessary. |
| Features could be achieved with platform channels + existing plugins | Use the plugins. Keep logic in Dart. |

## Justification Document

Before writing native code, **write a brief justification** in the app's `README.md`:

```markdown
## Native Modules

### Camera Encoder (Kotlin)
- **Why**: Flutter's camera plugin cannot access UVC devices. RootEncoder requires direct Android Camera2 API.
- **Platform**: Android only (iOS uses AVFoundation later).
- **Location**: `platform/android/plugins/camera_encoder/`
- **Test**: JUnit 4 in `android/src/test/`.
```

Then code the module.

## Project Structure

Federated Flutter plugin under `platform/android/plugins/<name>/`:

```
platform/android/plugins/<name>/
├── pubspec.yaml               (federated plugin, Flutter package)
├── lib/
│   ├── <name>.dart            (Dart API exported to apps)
│   ├── <name>_method_channel.dart   (platform channel interface)
│   └── <name>_platform_interface.dart   (cross-platform abstraction)
├── android/
│   └── src/
│       ├── main/kotlin/io/penguintech/<name>/
│       │   └── <Name>Plugin.kt     (MethodChannel handler)
│       └── test/kotlin/io/penguintech/<name>/
│           └── <Name>PluginTest.kt (JUnit 4)
├── ios/
│   └── Classes/
│       ├── <Name>Plugin.swift       (MethodChannel handler)
│       └── <Name>PluginTests.swift  (XCTest)
├── test/
│   └── <name>_test.dart        (Dart unit + mock tests)
├── integration_test/
│   └── <name>_e2e_test.dart     (end-to-end on real device)
└── README.md                   (justification + usage docs)
```

Register in root `pubspec.yaml` workspace.

## Dart API

Keep it minimal — **no internal details leak out**:

```dart
// lib/camera_encoder.dart
import 'package:flutter/services.dart';

const _channel = MethodChannel('io.penguintech.camera_encoder');

abstract interface class CameraEncoderException implements Exception {
  final String message;
}

class CameraEncoder {
  /// Initialize the encoder with the given [deviceId].
  /// Throws [CameraEncoderException] if the device is not found.
  static Future<void> initialize(String deviceId) async {
    try {
      await _channel.invokeMethod('initialize', {'deviceId': deviceId});
    } catch (e) {
      throw CameraEncoderException('Failed to initialize: $e');
    }
  }

  /// Start encoding video to [rtmpUrl].
  /// Throws [CameraEncoderException] if the encoder is not initialized.
  static Future<void> startEncoding(String rtmpUrl) async {
    try {
      await _channel.invokeMethod('startEncoding', {'rtmpUrl': rtmpUrl});
    } catch (e) {
      throw CameraEncoderException('Failed to start encoding: $e');
    }
  }

  /// Stop encoding.
  static Future<void> stopEncoding() async {
    try {
      await _channel.invokeMethod('stopEncoding');
    } catch (e) {
      throw CameraEncoderException('Failed to stop encoding: $e');
    }
  }

  /// Stream of bitrate (kbps) during encoding.
  static Stream<int> get bitrateStream {
    return EventChannel('io.penguintech.camera_encoder/bitrate')
        .receiveBroadcastStream()
        .map((event) => event as int);
  }
}
```

## Kotlin Implementation

`android/src/main/kotlin/io/penguintech/camera_encoder/CameraEncoderPlugin.kt`:

```kotlin
package io.penguintech.camera_encoder

import android.hardware.camera2.CameraManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class CameraEncoderPlugin: FlutterPlugin, ActivityAware {
  private lateinit var channel: MethodChannel
  private lateinit var bitrateChannel: EventChannel
  private var encoder: RootEncoderBridge? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, "io.penguintech.camera_encoder")
    channel.setMethodCallHandler { call, result ->
      when (call.method) {
        "initialize" -> {
          val deviceId = call.argument<String>("deviceId") ?: return@setMethodCallHandler result.error(
            "INVALID_ARG", "deviceId required", null
          )
          try {
            encoder = RootEncoderBridge(deviceId)
            result.success(null)
          } catch (e: Exception) {
            result.error("INIT_FAILED", e.message, null)
          }
        }
        "startEncoding" -> {
          val rtmpUrl = call.argument<String>("rtmpUrl") ?: return@setMethodCallHandler result.error(
            "INVALID_ARG", "rtmpUrl required", null
          )
          try {
            encoder?.start(rtmpUrl)
            result.success(null)
          } catch (e: Exception) {
            result.error("START_FAILED", e.message, null)
          }
        }
        "stopEncoding" -> {
          try {
            encoder?.stop()
            result.success(null)
          } catch (e: Exception) {
            result.error("STOP_FAILED", e.message, null)
          }
        }
        else -> result.notImplemented()
      }
    }

    bitrateChannel = EventChannel(binding.binaryMessenger, "io.penguintech.camera_encoder/bitrate")
    bitrateChannel.setStreamHandler(object : EventChannel.StreamHandler {
      private var listener: ((Int) -> Unit)? = null

      override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        listener = { bitrate ->
          events?.success(bitrate)
        }
        encoder?.setBitrateListener(listener!!)
      }

      override fun onCancel(arguments: Any?) {
        listener?.let { encoder?.setBitrateListener(null) }
        listener = null
      }
    })
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    bitrateChannel.setStreamHandler(null)
    encoder?.close()
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    encoder?.setActivity(binding.activity)
  }

  override fun onDetachedFromActivity() {}
  override fun onReattachedToActivity(binding: ActivityPluginBinding) {}
  override fun onDetachedFromActivityForConfigChanges() {}
  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {}
}
```

## Kotlin Tests

`android/src/test/kotlin/io/penguintech/camera_encoder/CameraEncoderPluginTest.kt`:

```kotlin
package io.penguintech.camera_encoder

import org.junit.Test
import org.junit.Assert.*
import org.junit.Before

class CameraEncoderPluginTest {
  private lateinit var plugin: CameraEncoderPlugin

  @Before
  fun setUp() {
    plugin = CameraEncoderPlugin()
  }

  @Test
  fun testInitialize() {
    // Test setup and initialization
    assertNotNull(plugin)
  }

  @Test
  fun testStartStop() {
    // Test start/stop sequence
  }
}
```

## Dart Tests

`test/camera_encoder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:camera_encoder/camera_encoder.dart';

void main() {
  group('CameraEncoder', () {
    testWidgets('initializes without error', (tester) async {
      // Mock MethodChannel responses
      // Test initialization
    });

    testWidgets('emits bitrate changes', (tester) async {
      // Mock EventChannel
      // Subscribe to bitrateStream
      // Verify emissions
    });
  });
}
```

## Integration Tests

`integration_test/camera_encoder_e2e_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:camera_encoder/camera_encoder.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('CameraEncoder E2E', () {
    testWidgets('initializes on real device', (tester) async {
      // Test on emulator or real device
      // Access real camera if available
      // Verify initialization
    });
  });
}
```

## iOS Implementation (Swift)

`ios/Classes/CameraEncoderPlugin.swift`:

```swift
import Flutter

public class CameraEncoderPlugin: NSObject, FlutterPlugin {
  public static func dummy(methodCall: FlutterMethodCall, result: @escaping FlutterResult) {
    result(nil)
  }

  public static func register(with registrar: FlutterPluginRegistry) {
    let channel = FlutterMethodChannel(
      name: "io.penguintech.camera_encoder",
      binaryMessenger: registrar.messenger()
    )
    let instance = CameraEncoderPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func dummyMethodToEnforceBundling(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result(nil)
  }
}
```

(Full iOS implementation follows the same pattern as Kotlin.)

## In-App Usage

```dart
import 'package:camera_encoder/camera_encoder.dart';

// Somewhere in your feature module:
try {
  await CameraEncoder.initialize('camera-device-0');
  await CameraEncoder.startEncoding('rtmp://live.example.com/stream');

  // Monitor bitrate
  CameraEncoder.bitrateStream.listen((bitrate) {
    print('Encoding bitrate: ${bitrate}kbps');
  });

  // Later: stop
  await CameraEncoder.stopEncoding();
} on CameraEncoderException catch (e) {
  print('Encoder error: ${e.message}');
}
```

## Rules

1. **Dart API is the contract** — native code is an implementation detail
2. **No internal details leak** — exceptions are wrapped, interfaces are minimal
3. **Both platforms or document why not** — every module needs Kotlin AND Swift (or a note explaining why one is deferred)
4. **Test on real hardware** — emulator behavior ≠ device behavior (especially for camera, audio, sensors)
5. **Minimize native code** — move logic to Dart; native only for platform APIs
6. **Keep dependencies minimal** — fewer native deps = fewer maintenance headaches

## Checklist Before Adding Native

- [ ] No Flutter package exists for this
- [ ] Existing packages are unmaintained or incomplete
- [ ] Performance need is measured and justified
- [ ] Justification written in app README.md
- [ ] Kotlin implementation complete + JUnit tests
- [ ] Swift implementation complete + XCTest tests (or documented as "deferred")
- [ ] Dart API minimal and non-leaky
- [ ] Tested on real device (or documented as "emulator-only")

See `APP_STANDARDS.md` for the native-module policy and platform targets.
