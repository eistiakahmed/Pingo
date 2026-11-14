import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_exceptions.dart';

/// Centralized HTTP client handling JSON serialization, authentication tokens,
/// timeouts, and RFC 7807 error parsing.
class ApiClient {
  final http.Client _client;
  String? _authToken;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  /// Sets the active JWT authentication token
  void setAuthToken(String? token) {
    _authToken = token;
  }

  String? get authToken => _authToken;

  Map<String, String> _headers([Map<String, String>? extra]) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  Future<dynamic> get(String url, {Map<String, String>? headers}) async {
    try {
      final uri = Uri.parse(url);
      final response = await _client
          .get(uri, headers: _headers(headers))
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.network(e);
    }
  }

  Future<dynamic> post(
    String url, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    try {
      final uri = Uri.parse(url);
      final response = await _client
          .post(
            uri,
            headers: _headers(headers),
            body: body != null ? jsonEncode(body) : null,
            encoding: utf8,
          )
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.network(e);
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic decoded;
    if (response.bodyBytes.isNotEmpty) {
      final bodyString = utf8.decode(response.bodyBytes);
      try {
        decoded = jsonDecode(bodyString);
      } catch (_) {
        decoded = bodyString;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    if (decoded is Map<String, dynamic>) {
      throw ApiException.fromJson(response.statusCode, decoded);
    }

    throw ApiException(
      statusCode: response.statusCode,
      title: 'HTTP Error ${response.statusCode}',
      detail: response.body,
    );
  }

  void close() {
    _client.close();
  }
}
