import 'package:http/http.dart' as http;

/// Creates an independent, unsent copy of [request] so it can be sent again
/// — shared by [AuthClient] (401 → refresh → replay) and `RetryClient`
/// (exponential-backoff retry), both of which must be able to send the same
/// logical request more than once.
///
/// `http.BaseRequest.finalize()` marks a request finalized on its first
/// send; sending the same instance a second time throws `StateError`
/// against any real client (`IOClient` included) — so every retried or
/// replayed attempt needs its own fresh copy, never the original instance.
///
/// Supports [http.Request] (body already buffered in memory) and
/// [http.MultipartRequest] whose files have not yet been sent — a
/// [http.MultipartFile] can only be finalized once ever (by design in
/// `package:http`), so a request whose files are already finalized cannot
/// be copied safely and is rejected rather than risking a drained stream.
/// [http.StreamedRequest] can never be copied since its body stream is
/// consumed on first read; any other request type is rejected as
/// unsupported.
http.BaseRequest copyRequestForReplay(http.BaseRequest request) {
  late http.BaseRequest copy;
  if (request is http.Request) {
    copy = http.Request(request.method, request.url)
      ..encoding = request.encoding
      ..bodyBytes = request.bodyBytes;
  } else if (request is http.MultipartRequest) {
    if (request.files.any((file) => file.isFinalized)) {
      throw StateError(
        'Cannot retry/replay a MultipartRequest whose files have already '
        'been sent once — a MultipartFile body can only be read one time, '
        'so reusing it in a second request would risk sending a drained '
        'stream.',
      );
    }
    copy = http.MultipartRequest(request.method, request.url)
      ..fields.addAll(request.fields)
      ..files.addAll(request.files);
  } else if (request is http.StreamedRequest) {
    throw StateError(
      'Cannot retry/replay a StreamedRequest (streamed body has been '
      'consumed).',
    );
  } else {
    throw UnsupportedError('Unknown request type: ${request.runtimeType}');
  }
  copy.persistentConnection = request.persistentConnection;
  copy.followRedirects = request.followRedirects;
  copy.maxRedirects = request.maxRedirects;
  copy.headers.addAll(request.headers);
  return copy;
}
