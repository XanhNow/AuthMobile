import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../errors/app_exception.dart';
import '../storage/secure_token_store.dart';
import 'api_result.dart';

typedef JsonMap = Map<String, dynamic>;

class ApiClient {
  ApiClient({
    required String baseUrl,
    required SecureTokenStore tokenStore,
    http.Client? httpClient,
    Uuid? uuid,
  }) : _baseUri = Uri.parse(baseUrl.replaceAll(RegExp(r'/+$'), '')),
       _tokenStore = tokenStore,
       _http = httpClient ?? http.Client(),
       _uuid = uuid ?? const Uuid();

  final Uri _baseUri;
  final SecureTokenStore _tokenStore;
  final http.Client _http;
  final Uuid _uuid;

  Future<ApiEnvelope<T>> get<T>(
    String path,
    T Function(Object? json) decode, {
    bool authenticated = true,
  }) async {
    final uri = _uri(path);
    final response = await _http.get(
      uri,
      headers: await _headers(authenticated: authenticated),
    );
    return _parse(response, decode, method: 'GET', uri: uri);
  }

  Future<ApiEnvelope<T>> post<T>(
    String path,
    Object body,
    T Function(Object? json) decode, {
    bool authenticated = true,
    String? idempotencyKey,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = _uri(path);
    final response = await _http.post(
      uri,
      headers: await _headers(
        authenticated: authenticated,
        idempotencyKey: idempotencyKey,
        extraHeaders: extraHeaders,
      ),
      body: jsonEncode(body),
    );
    return _parse(response, decode, method: 'POST', uri: uri);
  }

  Future<void> delete(
    String path, {
    bool authenticated = true,
    String? idempotencyKey,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = _uri(path);
    final response = await _http.delete(
      uri,
      headers: await _headers(
        authenticated: authenticated,
        idempotencyKey: idempotencyKey,
        extraHeaders: extraHeaders,
      ),
    );
    _logResponse('DELETE', uri, response);
    if (response.statusCode == 204) {
      return;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwError(response);
    }
  }

  Uri _uri(String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return _baseUri.replace(path: '${_baseUri.path}/$normalized');
  }

  Future<Map<String, String>> _headers({
    required bool authenticated,
    String? idempotencyKey,
    Map<String, String>? extraHeaders,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-Correlation-Id': _uuid.v4(),
      'X-Contract-Version': 'v1',
      ...?extraHeaders,
    };
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    if (authenticated) {
      final tokens = await _tokenStore.read();
      if (tokens?.accessToken case final accessToken?) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    return headers;
  }

  ApiEnvelope<T> _parse<T>(
    http.Response response,
    T Function(Object? json) decode, {
    required String method,
    required Uri uri,
  }) {
    _logResponse(method, uri, response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _throwError(response);
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as JsonMap;
    return ApiEnvelope<T>(
      data: decode(json['data']),
      metadata: ApiMetadata.fromJson(json['metadata'] as JsonMap),
    );
  }

  Never _throwError(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as JsonMap;
      final error = ApiError.fromJson(json);
      final message = _friendlyErrorMessage(error);
      throw AppException(
        message,
        code: error.code,
        statusCode: response.statusCode,
      );
    } on FormatException {
      final reason = response.statusCode == 504
          ? 'Gateway timeout. Backend did not respond in time.'
          : 'Unexpected server response.';
      throw AppException(reason, statusCode: response.statusCode);
    }
  }

  String _friendlyErrorMessage(ApiError error) {
    if (error.code == 'CONFLICT' &&
        error.message.contains('Auth_Login_App returned 400')) {
      return 'Phone number was rejected by Auth Login. Please use a new Vietnamese mobile number.';
    }
    if (error.code == 'CONFLICT' &&
        error.message.contains('Auth_Login_App returned 409')) {
      return 'Số điện thoại này đã được đăng ký. Vui lòng dùng số khác hoặc chuyển sang đăng nhập.';
    }
    return error.message;
  }

  void _logResponse(String method, Uri uri, http.Response response) {
    if (!kDebugMode) {
      return;
    }
    final requestId = response.headers['x-request-id'];
    final requestIdSuffix = requestId == null ? '' : ' requestId=$requestId';
    final errorSuffix = response.statusCode >= 400
        ? _debugErrorSuffix(response)
        : '';
    debugPrint(
      'XanhNow API $method ${uri.path} -> ${response.statusCode}$requestIdSuffix$errorSuffix',
    );
  }

  String _debugErrorSuffix(http.Response response) {
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as JsonMap;
      final code = json['code'];
      final message = json['message'];
      if (code is String && message is String) {
        return ' code=$code message=$message';
      }
      if (message is String) {
        return ' message=$message';
      }
    } on Object {
      return '';
    }
    return '';
  }
}
