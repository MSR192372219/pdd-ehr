import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

/// Response wrapper for API calls
class ApiResponse<T> {
  final bool success;
  final int statusCode;
  final T? data;
  final String? errorMessage;

  const ApiResponse({
    required this.success,
    required this.statusCode,
    this.data,
    this.errorMessage,
  });

  factory ApiResponse.success(T data, {int statusCode = 200}) {
    return ApiResponse(
      success: true,
      statusCode: statusCode,
      data: data,
    );
  }

  factory ApiResponse.failure(String message, {int statusCode = 500}) {
    return ApiResponse(
      success: false,
      statusCode: statusCode,
      errorMessage: message,
    );
  }
}

/// Secure HTTP client interface connecting Flutter to the Private Cloud Backend.
/// Uses Firebase Authentication ID tokens for cryptographic identity transmission.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final http.Client _httpClient = http.Client();

  /// Obtains the cryptographically signed Firebase ID token for the currently logged-in user.
  Future<String?> _getAuthToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      // Force refresh if near expiration
      return await user.getIdToken();
    } catch (e) {
      debugPrint('ApiClient: Error acquiring Firebase ID token: $e');
      return null;
    }
  }

  /// Builds standard headers, appending Bearer authentication if requested.
  Future<Map<String, String>> _buildHeaders({bool requireAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAuth) {
      final token = await _getAuthToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// Pings the backend health endpoint without requiring authentication.
  Future<ApiResponse<Map<String, dynamic>>> checkBackendHealth() async {
    return get(ApiConfig.rootHealth, requireAuth: false);
  }

  /// Performs a GET request to the Private Cloud Backend.
  Future<ApiResponse<Map<String, dynamic>>> get(
    String endpoint, {
    bool requireAuth = true,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _buildHeaders(requireAuth: requireAuth);

      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(ApiConfig.connectTimeout);

      return _handleResponse(response);
    } on SocketException catch (e) {
      return ApiResponse.failure('Unable to connect to backend server: ${e.message}', statusCode: 503);
    } on http.ClientException catch (e) {
      return ApiResponse.failure('Client network error: ${e.message}', statusCode: 503);
    } catch (e) {
      return ApiResponse.failure('Unexpected error: $e', statusCode: 500);
    }
  }

  /// Performs a POST request to the Private Cloud Backend.
  Future<ApiResponse<Map<String, dynamic>>> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool requireAuth = true,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final headers = await _buildHeaders(requireAuth: requireAuth);

      final response = await _httpClient
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(ApiConfig.connectTimeout);

      return _handleResponse(response);
    } on SocketException catch (e) {
      return ApiResponse.failure('Unable to connect to backend server: ${e.message}', statusCode: 503);
    } on http.ClientException catch (e) {
      return ApiResponse.failure('Client network error: ${e.message}', statusCode: 503);
    } catch (e) {
      return ApiResponse.failure('Unexpected error: $e', statusCode: 500);
    }
  }

  ApiResponse<Map<String, dynamic>> _handleResponse(http.Response response) {
    try {
      final dynamic body = jsonDecode(response.body);
      final Map<String, dynamic> data = (body is Map<String, dynamic>)
          ? body
          : {'data': body};

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success(data, statusCode: response.statusCode);
      } else {
        final message = data['message']?.toString() ??
            data['detail']?.toString() ??
            'Request failed with status ${response.statusCode}';
        return ApiResponse.failure(message, statusCode: response.statusCode);
      }
    } catch (e) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.success({}, statusCode: response.statusCode);
      }
      return ApiResponse.failure(
        'Server returned HTTP ${response.statusCode} (${response.reasonPhrase})',
        statusCode: response.statusCode,
      );
    }
  }
}
