import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../models/auth_models.dart';
import 'storage_service.dart';

class FaceAuthResult {
  final bool success;
  final String message;
  final double? similarity;
  final UserProfile? user;
  final String? token;

  FaceAuthResult({
    required this.success,
    required this.message,
    this.similarity,
    this.user,
    this.token,
  });
}

class FaceAuthService {
  final http.Client _client;

  FaceAuthService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, String>> _authHeaders() async {
    final token = await StorageService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Giải mã an toàn chuỗi JSON từ server, tránh crash FormatException
  Map<String, dynamic>? _tryDecode(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Giải mã an toàn chuỗi nhị phân UTF-8 từ server
  String _decodeBody(http.Response response) {
    try {
      if (response.bodyBytes.isEmpty) return '';
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (_) {
      try {
        return response.body;
      } catch (_) {
        return '';
      }
    }
  }

  /// Xử lý thông báo lỗi chuẩn hóa theo HTTP status code
  String _parseErrorMessage(http.Response response, String defaultMsg) {
    final body = _decodeBody(response);
    final data = _tryDecode(body);
    if (data != null) {
      final msg = data['message'] ?? data['Message'];
      if (msg != null && msg.toString().trim().isNotEmpty) {
        return msg.toString().trim();
      }
    }

    switch (response.statusCode) {
      case 400:
        return 'Ảnh không hợp lệ hoặc không phát hiện được khuôn mặt rõ ràng. Vui lòng chụp chính diện và đủ sáng.';
      case 401:
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại tài khoản.';
      case 403:
        return 'Tài khoản chưa được kích hoạt hoặc không có quyền thao tác sinh trắc học.';
      case 404:
        return 'Không tìm thấy dịch vụ nhận diện khuôn mặt trên máy chủ.';
      case 413:
        return 'Kích thước ảnh quá lớn. Vui lòng chọn hoặc chụp ảnh dưới 6MB.';
      case 500:
        return 'Máy chủ AI nhận diện khuôn mặt (HTTP 500): Môi trường máy chủ đám mây chưa nạp mô hình ArcFace ONNX. Vui lòng thử lại sau hoặc sử dụng máy chủ nội bộ.';
      case 502:
      case 503:
      case 504:
        return 'Dịch vụ nhận diện khuôn mặt tạm thời không phản hồi (Mã lỗi ${response.statusCode}). Vui lòng thử lại sau.';
      default:
        return '$defaultMsg (Mã lỗi: ${response.statusCode})';
    }
  }

  /// Đăng ký / Cập nhật khuôn mặt của tài khoản hiện tại (Yêu cầu JWT)
  /// Backend: POST /api/Authenticate/register-face
  Future<FaceAuthResult> registerFace(String base64Image) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(ApiConstants.registerFace);

      final response = await _client
          .post(
            url,
            headers: headers,
            body: jsonEncode({'faceDataBase64': base64Image}),
          )
          .timeout(const Duration(seconds: 25));

      final body = _decodeBody(response);
      final data = _tryDecode(body);

      if (response.statusCode == 200 &&
          (data?['status'] == true || data?['Status'] == true)) {
        return FaceAuthResult(
          success: true,
          message: data?['message'] ??
              data?['Message'] ??
              'Đăng ký khuôn mặt thành công!',
        );
      } else {
        return FaceAuthResult(
          success: false,
          message: _parseErrorMessage(response, 'Đăng ký khuôn mặt thất bại'),
        );
      }
    } on SocketException {
      return FaceAuthResult(
        success: false,
        message:
            'Không thể kết nối đến máy chủ KidGuard. Vui lòng kiểm tra kết nối mạng.',
      );
    } on TimeoutException {
      return FaceAuthResult(
        success: false,
        message:
            'Quá thời gian kết nối tới máy chủ AI (Timeout 25s). Vui lòng thử lại.',
      );
    } on FormatException {
      return FaceAuthResult(
        success: false,
        message: 'Dữ liệu phản hồi từ máy chủ không đúng định dạng JSON.',
      );
    } catch (e) {
      return FaceAuthResult(
        success: false,
        message: 'Lỗi kết nối khi đăng ký khuôn mặt: $e',
      );
    }
  }

  /// Xóa dữ liệu khuôn mặt của tài khoản hiện tại
  /// Backend: DELETE /api/Authenticate/face
  Future<FaceAuthResult> deleteFace() async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(ApiConstants.deleteFace);

      final response = await _client
          .delete(url, headers: headers)
          .timeout(const Duration(seconds: 15));

      final body = _decodeBody(response);
      final data = _tryDecode(body);

      if (response.statusCode == 200 &&
          (data?['status'] == true || data?['Status'] == true)) {
        return FaceAuthResult(
          success: true,
          message:
              data?['message'] ?? data?['Message'] ?? 'Đã xóa dữ liệu khuôn mặt.',
        );
      } else {
        return FaceAuthResult(
          success: false,
          message: _parseErrorMessage(response, 'Xóa dữ liệu khuôn mặt thất bại'),
        );
      }
    } on SocketException {
      return FaceAuthResult(
        success: false,
        message:
            'Không thể kết nối đến máy chủ KidGuard. Vui lòng kiểm tra kết nối mạng.',
      );
    } on TimeoutException {
      return FaceAuthResult(
        success: false,
        message: 'Quá thời gian kết nối tới máy chủ. Vui lòng thử lại.',
      );
    } catch (e) {
      return FaceAuthResult(
        success: false,
        message: 'Lỗi khi xóa khuôn mặt: $e',
      );
    }
  }

  /// Đăng nhập bằng khuôn mặt: so khớp vector ArcFace trên backend
  /// Backend: POST /api/Authenticate/login-face
  Future<FaceAuthResult> loginWithFace({
    required String username,
    required String base64Image,
  }) async {
    try {
      final url = Uri.parse(ApiConstants.loginFace);

      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'username': username.trim(),
              'faceDataBase64': base64Image,
            }),
          )
          .timeout(const Duration(seconds: 25));

      final body = _decodeBody(response);
      final data = _tryDecode(body);

      if (response.statusCode == 200 &&
          (data?['status'] == true || data?['Status'] == true)) {
        final token = data?['token'] as String?;
        final role = data?['role'] as String? ?? 'Parent';
        final userProfile = UserProfile(
          id: data?['userId'] ?? username,
          username: username,
          email: data?['email'] ?? '',
          fullName: data?['fullName'] ?? username,
          roles: [role],
          emailConfirmed: true,
        );

        if (token != null) {
          await StorageService.saveToken(token);
          await StorageService.saveUser(userProfile);
        }

        return FaceAuthResult(
          success: true,
          message: data?['message'] ?? 'Đăng nhập bằng khuôn mặt thành công!',
          similarity: (data?['similarity'] as num?)?.toDouble(),
          user: userProfile,
          token: token,
        );
      } else {
        final similarity = (data?['similarity'] as num?)?.toDouble();
        return FaceAuthResult(
          success: false,
          message: _parseErrorMessage(
            response,
            'Khuôn mặt không khớp, đăng nhập thất bại!',
          ),
          similarity: similarity,
        );
      }
    } on SocketException {
      return FaceAuthResult(
        success: false,
        message:
            'Không thể kết nối đến máy chủ KidGuard. Vui lòng kiểm tra kết nối mạng.',
      );
    } on TimeoutException {
      return FaceAuthResult(
        success: false,
        message: 'Quá thời gian kết nối tới máy chủ (Timeout). Vui lòng thử lại.',
      );
    } catch (e) {
      return FaceAuthResult(
        success: false,
        message: 'Lỗi đăng nhập khuôn mặt: $e',
      );
    }
  }

  /// Kiểm tra tài khoản hiện tại đã đăng ký khuôn mặt chưa (GET /api/Authenticate/me)
  Future<bool> checkHasFace() async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(ApiConstants.me);
      final response = await _client
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = _decodeBody(response);
        final data = _tryDecode(body);
        return data?['hasFace'] == true || data?['HasFace'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

