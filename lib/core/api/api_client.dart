import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../auth/auth_controller.dart';
import '../config.dart';

/// Thin JSON client for lumo-api-gateway. Like the website's getJson(), a
/// failed request never throws — it yields null and callers fall back to an
/// empty state, so one backend service being down (or cold-starting on
/// Render) can't take a whole screen down with it.
class ApiClient {
  ApiClient({http.Client? httpClient, this.tokenProvider}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// Supplies the Clerk session token for authenticated calls (wired up with
  /// sign-in). Null / returning null means the call goes out anonymous.
  final Future<String?> Function()? tokenProvider;

  static const _timeout = Duration(seconds: 20);

  Uri uri(String path, [Map<String, Object?>? params]) {
    final query = <String, String>{
      for (final entry in (params ?? const {}).entries)
        if (entry.value != null && '${entry.value}'.isNotEmpty) entry.key: '${entry.value}',
    };
    return Uri.parse('$apiBaseUrl$path').replace(queryParameters: query.isEmpty ? null : query);
  }

  Future<Map<String, String>> _headers({bool json = false}) async {
    final token = await tokenProvider?.call();
    return {if (json) 'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  }

  Future<Object?> getJson(String path, [Map<String, Object?>? params]) async {
    try {
      final response = await _http.get(uri(path, params), headers: await _headers()).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  Future<http.Response?> send(String method, String path, {Object? body, Map<String, Object?>? params}) async {
    try {
      final request = http.Request(method, uri(path, params))..headers.addAll(await _headers(json: body != null));
      if (body != null) request.body = jsonEncode(body);
      return await http.Response.fromStream(await _http.send(request).timeout(_timeout));
    } catch (_) {
      return null;
    }
  }

  /// A [send] response's JSON body, or null if it isn't JSON.
  static Object? decode(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  /// The gateway sometimes wraps collections as `{ value: T[], Count: n }`
  /// (OData-style) and sometimes returns a bare array — both are handled.
  static List<Map<String, dynamic>> unwrapList(Object? data) {
    final list = data is List ? data : (data is Map && data['value'] is List ? data['value'] as List : const []);
    return list.whereType<Map<String, dynamic>>().toList();
  }
}

/// Signed in, every gateway call carries the Clerk session token.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(tokenProvider: () => ref.read(authProvider.notifier).getToken()));
