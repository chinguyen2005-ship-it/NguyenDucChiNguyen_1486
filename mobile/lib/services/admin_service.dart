import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../models/admin_user_model.dart';
import 'device_service.dart';
import 'storage_service.dart';

class AdminService {
  final http.Client _client;

  AdminService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await StorageService.getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // GET /api/Admin/users?search=...
  Future<ApiResponse<List<AdminUserModel>>> getUsers({String? search}) async {
    try {
      final headers = await _getAuthHeaders();
      var url = ApiConstants.adminUsers;
      if (search != null && search.trim().isNotEmpty) {
        url += '?search=${Uri.encodeQueryComponent(search.trim())}';
      }

      final response = await _client.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          final list = decoded
              .map((e) => AdminUserModel.fromJson(e as Map<String, dynamic>))
              .toList();
          return ApiResponse(
            success: true,
            data: list,
            message: 'Tải danh sách người dùng thành công',
            statusCode: 200,
          );
        }
        return ApiResponse(
          success: true,
          data: [],
          message: 'Danh sách trống',
          statusCode: 200,
        );
      } else if (response.statusCode == 403) {
        return ApiResponse(
          success: false,
          message: 'Chỉ Quản trị viên (Admin) mới có quyền xem danh sách người dùng!',
          statusCode: 403,
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'Lỗi tải người dùng (HTTP ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Lỗi kết nối máy chủ: $e',
        statusCode: 500,
      );
    }
  }

  // PUT /api/Admin/users/{username}/role
  Future<ApiResponse<bool>> setUserRole(String username, String role) async {
    try {
      final headers = await _getAuthHeaders();
      final url = ApiConstants.adminSetRole(username);

      final response = await _client.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({'role': role}),
      );

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final msg = decoded is Map<String, dynamic>
          ? (decoded['message'] ?? decoded['Message'] ?? '')
          : '';

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: true,
          message: msg.isNotEmpty ? msg : 'Cập nhật vai trò thành công',
          statusCode: 200,
        );
      } else {
        return ApiResponse(
          success: false,
          data: false,
          message: msg.isNotEmpty
              ? msg
              : 'Không thể cập nhật vai trò (HTTP ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Lỗi kết nối máy chủ: $e',
        statusCode: 500,
      );
    }
  }

  // PUT /api/Admin/users/{username}/unlock
  Future<ApiResponse<bool>> unlockUser(String username) async {
    try {
      final headers = await _getAuthHeaders();
      final url = ApiConstants.adminUnlockUser(username);

      final response = await _client.put(Uri.parse(url), headers: headers);

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final msg = decoded is Map<String, dynamic>
          ? (decoded['message'] ?? decoded['Message'] ?? '')
          : '';

      if (response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: true,
          message: msg.isNotEmpty ? msg : 'Mở khóa tài khoản thành công',
          statusCode: 200,
        );
      } else {
        return ApiResponse(
          success: false,
          data: false,
          message: msg.isNotEmpty
              ? msg
              : 'Không thể mở khóa tài khoản (HTTP ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Lỗi kết nối máy chủ: $e',
        statusCode: 500,
      );
    }
  }
}
