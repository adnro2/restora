import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Sends JSON summaries only. No camera/frame/landmark upload method exists.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.token,
    http.Client? client,
    bool allowLocalHttp = true,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client() {
    if (baseUrl.scheme != 'https' &&
        !(allowLocalHttp &&
            baseUrl.scheme == 'http' &&
            const {
              'localhost',
              '127.0.0.1',
              '10.0.2.2',
            }.contains(baseUrl.host))) {
      throw ArgumentError(
        'Use HTTPS, or local HTTP for Android emulator development.',
      );
    }
  }

  final Uri baseUrl;
  final String? Function() token;
  final Duration timeout;
  final http.Client _client;

  Future<Map<String, dynamic>> get(String path) => _request('GET', path);

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) => _request('POST', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (authenticated) {
      final accessToken = token();
      if (accessToken == null || accessToken.isEmpty) {
        throw const ApiException(
          'authentication_required',
          'Please sign in to continue.',
          statusCode: 401,
        );
      }
      headers['Authorization'] = 'Bearer $accessToken';
    }
    try {
      final request = http.Request(method, baseUrl.resolve(path))
        ..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final response = await (() async {
        final streamed = await _client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(timeout);
      Map<String, dynamic>? decoded;
      try {
        final value = jsonDecode(utf8.decode(response.bodyBytes));
        if (value is Map<String, dynamic>) decoded = value;
      } on FormatException {
        // Proxies can return HTML, including on errors; handle it below.
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = decoded?['error'];
        final code = error is Map<String, dynamic> ? error['code'] : null;
        final message = error is Map<String, dynamic> ? error['message'] : null;
        final fallback = switch (response.statusCode) {
          401 => 'Your sign-in expired. Sign in again, then retry.',
          403 => 'This account cannot access that item.',
          409 =>
            'This session conflicts with an existing record. Contact the demo developer.',
          422 => 'Some details are invalid. Please check and try again.',
          _ => 'The server is unavailable. Please try again.',
        };
        throw ApiException(
          code is String ? code : 'http_error',
          message is String && message.isNotEmpty ? message : fallback,
          statusCode: response.statusCode,
        );
      }
      if (decoded == null) {
        throw const ApiException(
          'invalid_response',
          'The server returned an unexpected response. Try again.',
        );
      }
      return decoded;
    } on TimeoutException {
      throw const ApiException(
        'timeout',
        'The request timed out. Check your connection and retry.',
      );
    } on SocketException {
      throw const ApiException(
        'network_error',
        'Cannot connect. Check your internet connection and retry.',
      );
    } on http.ClientException {
      throw const ApiException(
        'network_error',
        'Cannot connect. Check your internet connection and retry.',
      );
    } on HandshakeException {
      throw const ApiException(
        'network_error',
        'A secure connection could not be established.',
      );
    }
  }

  void close() => _client.close();
}
