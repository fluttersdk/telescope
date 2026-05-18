/// An immutable HTTP request/response record captured by a [TelescopeHttpAdapter].
class HttpRequestRecord {
  HttpRequestRecord({
    required this.url,
    required this.method,
    required this.statusCode,
    required this.durationMs,
    required this.isError,
    required this.timestamp,
    this.requestHeaders,
    this.requestBody,
    this.responseBody,
    this.attributedHeuristically = false,
  });

  final String url;
  final String method;
  final int statusCode;
  final int durationMs;
  final bool isError;
  final DateTime timestamp;
  final Map<String, String>? requestHeaders;
  final String? requestBody;
  final String? responseBody;

  /// True when the adapter could not exactly match this response to its request
  /// (concurrent requests in flight). The attribution is best-effort FIFO.
  final bool attributedHeuristically;

  Map<String, dynamic> toJson() => {
        'url': url,
        'method': method,
        'statusCode': statusCode,
        'durationMs': durationMs,
        'isError': isError,
        'timestamp': timestamp.toIso8601String(),
        if (requestHeaders != null) 'requestHeaders': requestHeaders,
        if (requestBody != null) 'requestBody': requestBody,
        if (responseBody != null) 'responseBody': responseBody,
        if (attributedHeuristically) 'attributedHeuristically': true,
      };
}
