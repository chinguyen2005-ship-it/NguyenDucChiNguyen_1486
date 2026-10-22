import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../models/auth_models.dart';
import 'storage_service.dart';

class AuthService {
  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  // POST /api/Authenticate/register
  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
    String role = 'Parent',
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(ApiConstants.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'initials': fullName.length > 10
              ? fullName.substring(0, 10)
              : fullName,
          'role': role,
        }),
      );

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return AuthResponse.fromJson(data);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối máy chủ KidGuard: $e',
      );
    }
  }

  // POST /api/Authenticate/confirm-email
  Future<AuthResponse> confirmEmail({
    required String email,
    required String otpCode,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(ApiConstants.confirmEmail),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'code': otpCode}),
      );

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return AuthResponse.fromJson(data);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối máy chủ nhóm: $e',
      );
    }
  }

  // POST /api/Authenticate/resend-confirmation
  Future<AuthResponse> resendConfirmation({required String email}) async {
    try {
      final response = await _client.post(
        Uri.parse(ApiConstants.resendConfirmation),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return AuthResponse.fromJson(data);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối máy chủ nhóm: $e',
      );
    }
  }

  // Resend OTP / Email confirmation helper
  Future<AuthResponse> resendOtp({
    required String email,
    String? username,
    int purpose = 1,
  }) async {
    if (purpose == 1) {
      return resendConfirmation(email: email);
    }
    return resendConfirmation(email: email);
  }

  // POST /api/Authenticate/login
  Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(ApiConstants.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return AuthResponse.fromJson(data);
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối máy chủ nhóm: $e',
      );
    }
  }

  // POST /api/Authenticate/verify-otp
  Future<AuthResponse> verifyOtp({
    required String username,
    required String otpCode,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(ApiConstants.verifyOtp),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'otpCode': otpCode}),
      );

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final authResponse = AuthResponse.fromJson(data);

      if (authResponse.success && authResponse.token != null) {
        await StorageService.saveToken(authResponse.token!);
        // Fetch full profile from /api/Authenticate/me
        final fullProfile = await getCurrentUser();
        if (fullProfile != null) {
          await StorageService.saveUser(fullProfile);
        }
      }

      return authResponse;
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Lỗi kết nối máy chủ nhóm: $e',
      );
    }
  }

  // GET /api/Authenticate/me
  Future<UserProfile?> getCurrentUser() async {
    final token = await StorageService.getToken();
    if (token == null) return null;

    try {
      final response = await _client.get(
        Uri.parse(ApiConstants.me),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final user = UserProfile.fromJson(data);
        await StorageService.saveUser(user);
        return user;
      } else {
        await StorageService.clearAuth();
        return null;
      }
    } catch (_) {
      return await StorageService.getUser();
    }
  }

  // Test role endpoints on group backend
  Future<Map<String, dynamic>> testRoleEndpoint(String endpointUrl) async {
    final token = await StorageService.getToken();
    try {
      final response = await _client.get(
        Uri.parse(endpointUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      dynamic body;
      try {
        body = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        body = response.body;
      }

      return {'statusCode': response.statusCode, 'data': body};
    } catch (e) {
      return {'statusCode': 500, 'error': e.toString()};
    }
  }

  Future<void> logout() async {
    await StorageService.clearAuth();
  }
}
