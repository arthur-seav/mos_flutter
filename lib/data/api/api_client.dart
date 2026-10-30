import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A failed call to the MOS backend, with the message to show the customer.
///
/// [status] is the HTTP status (0 when the server could not be reached) and
/// [code] the backend's error code (`ordering_paused`, `bad_credentials`, ...).
class ApiException implements Exception {
  const ApiException(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  @override
  String toString() => message;
}

/// Sends JSON to the Spring Boot backend and reads JSON back (`/api/app/**`).
///
/// One instance is shared by every API repository, so the sign-in token set
/// by the auth repository is sent with every later call.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final Duration timeout;
  final http.Client _client;

  /// The bearer token of the signed-in customer, or null.
  String? token;

  static const unreachableMessage =
      "Can't reach the store right now. Check your connection and try again.";

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body ?? const {});

  Future<dynamic> put(String path, Object? body) =>
      _send('PUT', path, body: body);

  /// A path the backend returns (such as `/uploads/latte.jpg`) as a full URL.
  String? resolve(String? path) {
    if (path == null || path.isEmpty) return null;
    return baseUrl.resolve(path).toString();
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final request = http.Request(
      method,
      baseUrl.resolve(path).replace(queryParameters: query),
    );
    request.headers['Accept'] = 'application/json';
    final bearer = token;
    if (bearer != null) request.headers['Authorization'] = 'Bearer $bearer';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      );
    } on TimeoutException {
      throw const ApiException(0, 'unreachable', unreachableMessage);
    } on http.ClientException {
      throw const ApiException(0, 'unreachable', unreachableMessage);
    }
    final text = utf8.decode(response.bodyBytes);
    final json = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 400) throw _error(response.statusCode, json);
    return json;
  }

  static ApiException _error(int status, Object? json) {
    if (json is Map && json['message'] is String) {
      return ApiException(
        status,
        '${json['code'] ?? 'error'}',
        json['message'] as String,
      );
    }
    // Spring Security answers 401/403 without a body.
    return switch (status) {
      401 => const ApiException(401, 'not_signed_in', 'Please sign in again.'),
      403 => const ApiException(
        403,
        'forbidden',
        "You can't do that with this account.",
      ),
      _ => ApiException(
        status,
        'error',
        'Something went wrong ($status). Please try again.',
      ),
    };
  }
}
