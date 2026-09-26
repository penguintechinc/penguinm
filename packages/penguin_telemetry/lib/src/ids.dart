import 'dart:math';

/// Generates a 32-hex-character (128-bit) OTel trace ID using [random]
/// (normally [Random.secure] outside tests).
String generateTraceId(Random random) => _hex(random, 16);

/// Generates a 16-hex-character (64-bit) OTel span ID using [random]
/// (normally [Random.secure] outside tests).
String generateSpanId(Random random) => _hex(random, 8);

String _hex(Random random, int byteCount) {
  final buffer = StringBuffer();
  for (var i = 0; i < byteCount; i++) {
    buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}
