import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/constants.dart';

/// Centralized HTTP client that:
/// - Adds Supabase auth token to every request
/// - Handles 401 → triggers logout
/// - Adds timeout (30s default)
/// - Provides typed JSON helpers
class ApiClient {
  static final ApiClient _instance = ApiClient._();
  factory ApiClient() => _instance;
  ApiClient._();

  static const Duration _defaultTimeout = Duration(seconds: 30);

  String get _baseUrl => AppConstants.baseUrl;

  /// Manually stored token (used when currentSession is null after login).
  static String? _manualToken;
  static void setManualToken(String? token) => _manualToken = token;

  /// Get the backend-issued token after login. Falls back to Supabase only
  /// before `/login` has completed.
  String? get _accessToken =>
      _manualToken ?? Supabase.instance.client.auth.currentSession?.accessToken;

  Map<String, String> _headers({Map<String, String>? extra}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
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

  Future<http.Response> _handleResponse(Future<http.Response> request) async {
    try {
      final response = await request.timeout(_defaultTimeout);
      _checkApiVersion(response);
      if (response.statusCode == 401) {
        onUnauthorized?.call();
      }
      return response;
    } on TimeoutException {
      throw Exception('Request timed out. Please try again.');
    }
  }

  // --- HTTP Methods ---

  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? extraHeaders,
  }) {
    final uri =
        Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);
    return _handleResponse(
        http.get(uri, headers: _headers(extra: extraHeaders)));
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) {
    final uri = Uri.parse('$_baseUrl$path');
    return _handleResponse(
      http.post(uri,
          headers: _headers(extra: extraHeaders), body: jsonEncode(body)),
    );
  }

  Future<http.Response> put(
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) {
    final uri = Uri.parse('$_baseUrl$path');
    return _handleResponse(
      http.put(uri,
          headers: _headers(extra: extraHeaders), body: jsonEncode(body)),
    );
  }

  Future<http.Response> patch(
    String path, {
    Object? body,
    Map<String, String>? extraHeaders,
  }) {
    final uri = Uri.parse('$_baseUrl$path');
    return _handleResponse(
      http.patch(uri,
          headers: _headers(extra: extraHeaders), body: jsonEncode(body)),
    );
  }

  Future<http.Response> delete(
    String path, {
    Map<String, String>? extraHeaders,
  }) {
    final uri = Uri.parse('$_baseUrl$path');
    return _handleResponse(
      http.delete(uri, headers: _headers(extra: extraHeaders)),
    );
  }

  /// Upload raw bytes via multipart POST (works on Flutter web and native).
  Future<http.StreamedResponse> uploadBytes(
    String path, {
    required String fieldName,
    required List<int> bytes,
    String? fileName,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    final token = _accessToken;
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(http.MultipartFile.fromBytes(
      fieldName,
      bytes,
      filename: fileName,
    ));
    final streamed = await request.send().timeout(_defaultTimeout);
    _checkApiVersion(streamed);
    return streamed;
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
