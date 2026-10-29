import 'dart:convert';

/// A failed API call, carrying the server's error envelope:
/// `{ "error": { "code", "message", "field"? }, "traceId"? }`.
///
/// [status] is 0 when no response arrived at all (offline, DNS, timeout) --
/// see [isNetwork]. Callers branch on [code], never on [message], which is
/// English server text meant for logs.
class ApiException implements Exception {
  const ApiException({
    required this.status,
    this.code,
    this.message = '',
    this.field,
    this.traceId,
  });

  const ApiException.network([
    this.message = 'The server could not be reached.',
  ]) : status = 0,
       code = null,
       field = null,
       traceId = null;

  /// Parses the error envelope, tolerating bodies that are not one (a proxy's
  /// HTML 502 page, an empty 404).
  factory ApiException.fromResponse(
    int status,
    String body, {
    String? traceIdHeader,
  }) {
    String? code;
    var message = '';
    String? field;
    String? traceId = traceIdHeader;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          code = error['code'] as String?;
          message = (error['message'] as String?) ?? '';
          field = error['field'] as String?;
        }
        traceId = (decoded['traceId'] as String?) ?? traceId;
      }
    } on FormatException {
      // Not JSON; the status code is all there is.
    }
    return ApiException(
      status: status,
      code: code,
      message: message,
      field: field,
      traceId: traceId,
    );
  }

  /// HTTP status, or 0 when the request never got a response.
  final int status;

  /// Machine-readable error code from the envelope, e.g. `TOKEN_EXPIRED`.
  final String? code;

  final String message;

  /// Dotted path of the offending input, for validation errors.
  final String? field;

  /// Correlates with the server logs; worth showing in a bug report.
  final String? traceId;

  bool get isNetwork => status == 0;

  @override
  String toString() =>
      'ApiException($status${code == null ? '' : ' $code'}'
      '${traceId == null ? '' : ' trace=$traceId'}): $message';
}
