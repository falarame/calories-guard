import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/constants.dart';

/// Centralized HTTP client that:
/// - Adds Supabase auth token to every request
/// - Handles 401 → triggers logout
/// - Adds timeout (30s default, overridable per request)
/// - Provides typed JSON helpers
class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  static const Duration _defaultTimeout = Duration(seconds: 30);

  String get _baseUrl => AppConstants.baseUrl;

  /// Returns an HTTP client. In debug mode on non-web platforms we allow
  /// all certificates so that an incomplete SSL chain on the server does
  /// not block development. Release builds always use strict verification.
  http.Client _httpClient() {
    if (!kIsWeb && kDebugMode) {
      final inner = HttpClient()
        ..badCertificateCallback = (cert, host, port) => true;
      return IOClient(inner);
    }
    return http.Client();
  }

  /// Manually stored token (used when currentSession is null after login).
  static String? _manualToken;
  static void setManualToken(String? token) => _manualToken = token;

  /// Get the backend-issued token after login. Falls back to Supabase only
  /// before `/login` has completed.
  String? get _accessToken =>
      _manualToken ?? Supabase.instance.client.auth.currentSession?.accessToken;

  Map<String, String> _headers({Map<String, String>? extra}) {
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };
    final token = _accessToken;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  /// Callback invoked when a 401 response is received.
  /// Set this in your app (e.g., in main.dart) to navigate to login.
  void Function()? onUnauthorized;

  /// Callback invoked when the server reports an API version whose major
  /// segment differs from [AppConstants.kExpectedApiVersion]. App code
  /// should show a non-dismissable "please update" modal.
  void Function(String serverVersion)? onUpgradeRequired;

  /// Latest X-Api-Version header observed. `null` until the first response.
  String? lastServerApiVersion;

  /// True once we've seen a server response whose major version doesn't
  /// match [AppConstants.kExpectedApiVersion]. Remains true for the rest
  /// of the session — once old, always old until the user updates.
  bool isUpgradeRequired = false;

  void _checkApiVersion(http.BaseResponse response) {
    final serverVersion = response.headers['x-api-version'];
    if (serverVersion == null || serverVersion.isEmpty) return;
    lastServerApiVersion = serverVersion;
    final serverMajor = serverVersion.split('.').first;
    final clientMajor = AppConstants.kExpectedApiVersion.split('.').first;
    if (serverMajor != clientMajor && !isUpgradeRequired) {
      isUpgradeRequired = true;
      onUpgradeRequired?.call(serverVersion);
    }
  }

  Future<http.Response> _handleResponse(
    Future<http.Response> request, {
    Duration? timeout,
    String? label,
  }) async {
    final effectiveTimeout = timeout ?? _defaultTimeout;
    try {
      final response = await request.timeout(effectiveTimeout);
      _checkApiVersion(response);
      if (response.statusCode == 401) {
        onUnauthorized?.call();
      }
      return response;
    } on TimeoutException {
      final target = label == null || label.isEmpty ? 'request' : label;
      throw Exception(
        '$target timed out after ${effectiveTimeout.inSeconds}s. '
        'Please try again.',
      );
    } on http.ClientException {
      final target = label == null || label.isEmpty ? 'Network' : label;
      throw Exception('$target unavailable. Please check your connection.');
    }
  }

  // --- HTTP Methods ---

  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) {
    final uri =
        Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);
    return _handleResponse(
      _httpClient().get(uri, headers: _headers(extra: extraHeaders)),
      timeout: timeout,
      label: 'GET $path',
    );
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) {
    final uri = Uri.parse('$_baseUrl$path');
    return _handleResponse(
      _httpClient().post(uri,
          headers: _headers(extra: extraHeaders),
          body: utf8.encode(jsonEncode(body))),
      timeout: timeout,
      label: 'POST $path',
    );
  }

  Future<http.Response> put(
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) {
    final uri = Uri.parse('$_baseUrl$path');
    return _handleResponse(
      _httpClient().put(uri,
          headers: _headers(extra: extraHeaders),
          body: utf8.encode(jsonEncode(body))),
      timeout: timeout,
      label: 'PUT $path',
    );
  }

  Future<http.Response> patch(
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) {
    final uri = Uri.parse('$_baseUrl$path');
    return _handleResponse(
      _httpClient().patch(uri,
          headers: _headers(extra: extraHeaders),
          body: utf8.encode(jsonEncode(body))),
      timeout: timeout,
      label: 'PATCH $path',
    );
  }

  Future<http.Response> delete(
    String path, {
    Map<String, String>? extraHeaders,
    Duration? timeout,
  }) {
    final uri = Uri.parse('$_baseUrl$path');
    return _handleResponse(
      _httpClient().delete(uri, headers: _headers(extra: extraHeaders)),
      timeout: timeout,
      label: 'DELETE ${path.split('?').first}',
    );
  }

  /// Upload raw bytes via multipart POST (works on Flutter web and native).
  Future<http.StreamedResponse> uploadBytes(
    String path, {
    required String fieldName,
    required List<int> bytes,
    String? fileName,
    Map<String, String>? extraFields,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    final token = _accessToken;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    if (extraFields != null) {
      request.fields.addAll(extraFields);
    }
    request.files.add(http.MultipartFile.fromBytes(
      fieldName,
      bytes,
      filename: fileName,
      contentType: MediaType.parse(_detectMime(bytes)),
    ));
    final streamed = await request.send().timeout(_defaultTimeout);
    _checkApiVersion(streamed);
    return streamed;
  }

  static String _detectMime(List<int> b) {
    if (b.length > 3 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47) {
      return 'image/png';
    }
    if (b.length > 2 && b[0] == 0xFF && b[1] == 0xD8) return 'image/jpeg';
    if (b.length > 2 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46) {
      return 'image/gif';
    }
    if (b.length > 11 &&
        b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46 &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  /// Upload a file via multipart POST.
  Future<http.StreamedResponse> uploadFile(
    String path, {
    required String fieldName,
    required String filePath,
    String? fileName,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest('POST', uri);

    final token = _accessToken;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(await http.MultipartFile.fromPath(
      fieldName,
      filePath,
      filename: fileName,
    ));

    final streamed = await request.send().timeout(_defaultTimeout);
    _checkApiVersion(streamed);
    return streamed;
  }
}
