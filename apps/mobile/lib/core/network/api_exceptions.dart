/// RFC 7807 Problem Details API Exception
class ApiException implements Exception {
  final int statusCode;
  final String title;
  final String detail;
  final String typeUrl;
  final Map<String, dynamic>? raw;

  ApiException({
    required this.statusCode,
    required this.title,
    required this.detail,
    this.typeUrl = 'about:blank',
    this.raw,
  });

  factory ApiException.fromJson(int statusCode, Map<String, dynamic> json) {
    return ApiException(
      statusCode: statusCode,
      title: json['title'] as String? ?? 'API Error',
      detail: json['detail'] as String? ?? 'An unexpected error occurred.',
      typeUrl: json['type'] as String? ?? 'about:blank',
      raw: json,
    );
  }

  factory ApiException.network(dynamic error) {
    return ApiException(
      statusCode: 0,
      title: 'Network Error',
      detail: 'Could not connect to Pingo server: $error',
    );
  }

  @override
  String toString() => 'ApiException($statusCode): $title - $detail';
}
