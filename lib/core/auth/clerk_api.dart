import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config.dart';

/// One error from Clerk's Frontend API (`{errors: [{code, message,
/// long_message, meta: {param_name}}]}`). [message] is the text Clerk's own
/// components show (long_message when there is one).
class ClerkException implements Exception {
  const ClerkException({required this.code, required this.message, this.paramName});

  final String code;
  final String message;

  /// Which form field the error is about (`email_address`, `password`,
  /// `identifier`, `code`…), so the UI can show it under that field.
  final String? paramName;

  static ClerkException network() =>
      const ClerkException(code: 'network_error', message: 'Something went wrong. Please check your connection and try again.');

  @override
  String toString() => 'ClerkException($code): $message';
}

/// Thin client for Clerk's Frontend API in native mode (`_is_native=true`):
/// instead of cookies, the "client" is identified by a JWT that Clerk returns
/// in the `Authorization` response header and expects back on every request.
/// That token is the whole signed-in state, so it's kept in secure storage.
///
/// Deliberately small — only the endpoints the website's sign-in / sign-up
/// flows use. Reference: https://clerk.com/docs/reference/frontend-api
class ClerkApi {
  ClerkApi({http.Client? httpClient, FlutterSecureStorage? storage})
    : _http = httpClient ?? http.Client(),
      _storage = storage ?? const FlutterSecureStorage();

  final http.Client _http;
  final FlutterSecureStorage _storage;

  static const _tokenKey = 'clerk_client_token';
  static const _timeout = Duration(seconds: 20);

  String? _clientToken;
  bool _loaded = false;

  Future<void> _loadToken() async {
    if (_loaded) return;
    _loaded = true;
    try {
      _clientToken = await _storage.read(key: _tokenKey);
    } catch (_) {
      _clientToken = null;
    }
  }

  Future<void> _saveToken(String? token) async {
    if (token == null || token.isEmpty || token == _clientToken) return;
    _clientToken = token;
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {
      // Storage unavailable — the session just won't survive a restart.
    }
  }

  Future<void> forgetClient() async {
    _clientToken = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  /// Sends one request and returns the decoded body (`{response, client}`).
  /// Throws [ClerkException] for Clerk's own errors and for network failures.
  ///
  /// [file] sends a multipart upload instead of a form (the profile image).
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, String>? form,
    Map<String, String>? query,
    http.MultipartFile? file,
  }) async {
    await _loadToken();
    final uri = Uri.parse('$clerkFrontendApi/v1$path').replace(queryParameters: {'_is_native': 'true', ...?query});

    final http.BaseRequest request;
    if (file != null) {
      request = http.MultipartRequest(method, uri)..files.add(file);
    } else {
      final plain = http.Request(method, uri);
      if (form != null) {
        plain.headers['Content-Type'] = 'application/x-www-form-urlencoded';
        plain.body = Uri(queryParameters: form).query;
      }
      request = plain;
    }
    request.headers['Accept'] = 'application/json';
    request.headers['Accept-Language'] = 'en-US';
    if (_clientToken != null) request.headers['Authorization'] = _clientToken!;

    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } catch (_) {
      throw ClerkException.network();
    }

    await _saveToken(response.headers['authorization']);

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw ClerkException.network();
    }

    if (decoded is Map<String, dynamic> && decoded['errors'] is List && (decoded['errors'] as List).isNotEmpty) {
      final error = (decoded['errors'] as List).first as Map<String, dynamic>;
      throw ClerkException(
        code: '${error['code'] ?? 'unknown'}',
        message: '${error['long_message'] ?? error['message'] ?? 'Something went wrong.'}',
        paramName: (error['meta'] as Map<String, dynamic>?)?['param_name'] as String?,
      );
    }
    if (response.statusCode >= 400 || decoded is! Map<String, dynamic>) throw ClerkException.network();
    return decoded;
  }

  bool get hasClient => _clientToken != null;
  Future<bool> hasStoredClient() async {
    await _loadToken();
    return _clientToken != null;
  }
}
