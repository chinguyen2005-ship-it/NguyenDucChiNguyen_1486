import 'dart:convert';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../models/device_model.dart';
import 'storage_service.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String message;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.data,
    required this.message,
    required this.statusCode,
  });
}

class DeviceService {
  final http.Client _client;

  DeviceService({http.Client? client}) : _client = client ?? http.Client();

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

  // GET /api/ChildDeviceApi?search={query}
  Future<ApiResponse<List<ChildDeviceModel>>> getDevices({
    String? search,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      var url = ApiConstants.childDevices;
      if (search != null && search.trim().isNotEmpty) {
        url += '?search=${Uri.encodeQueryComponent(search.trim())}';
      }

      final response = await _client.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        if (decoded is List) {
          final list = decoded
              .map((e) => ChildDeviceModel.fromJson(e as Map<String, dynamic>))
              .toList();
          return ApiResponse(
            success: true,
            data: list,
            message: 'Tải danh sách thiết bị thành công',
            statusCode: 200,
          );
        }
        return ApiResponse(
          success: true,
          data: [],
          message: 'Danh sách trống',
          statusCode: 200,
        );
      } else if (response.statusCode == 401) {
        return ApiResponse(
          success: false,
          message: 'Chưa đăng nhập hoặc phiên làm việc đã hết hạn!',
          statusCode: 401,
        );
      } else if (response.statusCode == 403) {
        return ApiResponse(
          success: false,
          message: 'Bạn không có quyền truy cập danh sách thiết bị!',
          statusCode: 403,
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'Lỗi tải thiết bị: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Không thể kết nối máy chủ backend: $e',
        statusCode: 0,
      );
    }
  }

  // GET /api/ChildDeviceApi/{id}
  Future<ApiResponse<ChildDeviceModel>> getDeviceById(int id) async {
    try {
      final headers = await _getAuthHeaders();
      final url = ApiConstants.childDevice(id);

      final response = await _client.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        final decoded =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ApiResponse(
          success: true,
          data: ChildDeviceModel.fromJson(decoded),
          message: 'Lấy thông tin thiết bị thành công',
          statusCode: 200,
        );
      } else if (response.statusCode == 404) {
        return ApiResponse(
          success: false,
          message: 'Không tìm thấy thiết bị!',
          statusCode: 404,
        );
      } else if (response.statusCode == 403) {
        return ApiResponse(
          success: false,
          message: 'Bạn không có quyền thao tác trên thiết bị này!',
          statusCode: 403,
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'Lỗi lấy thiết bị: HTTP ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Lỗi kết nối máy chủ: $e',
        statusCode: 0,
      );
    }
  }

  // POST /api/ChildDeviceApi
  Future<ApiResponse<ChildDeviceModel>> addDevice(
    ChildDeviceUpsertDto dto,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final url = ApiConstants.childDevices;
      final body = jsonEncode(dto.toJson());

      final response = await _client.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201) {
        final decoded =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ApiResponse(
          success: true,
          data: ChildDeviceModel.fromJson(decoded),
          message: 'Thêm thiết bị cho trẻ thành công!',
          statusCode: 201,
        );
      } else if (response.statusCode == 400) {
        final errorMsg = _extractErrorMessage(
          response.bodyBytes,
          'Dữ liệu không hợp lệ!',
        );
        return ApiResponse(success: false, message: errorMsg, statusCode: 400);
      } else if (response.statusCode == 403) {
        return ApiResponse(
          success: false,
          message: 'Chỉ Phụ huynh hoặc Admin mới có quyền thêm thiết bị!',
          statusCode: 403,
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'Thêm thiết bị thất bại (HTTP ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Lỗi kết nối máy chủ: $e',
        statusCode: 0,
      );
    }
  }

  // PUT /api/ChildDeviceApi/{id}
  Future<ApiResponse<bool>> updateDevice(
    int id,
    ChildDeviceUpsertDto dto,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final url = ApiConstants.childDevice(id);
      final body = jsonEncode(dto.toJson());

      final response = await _client.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: true,
          message: 'Cập nhật thiết bị thành công!',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 400) {
        final errorMsg = _extractErrorMessage(
          response.bodyBytes,
          'Dữ liệu cập nhật không hợp lệ!',
        );
        return ApiResponse(success: false, message: errorMsg, statusCode: 400);
      } else if (response.statusCode == 403) {
        return ApiResponse(
          success: false,
          message: 'Bạn không có quyền chỉnh sửa thiết bị này!',
          statusCode: 403,
        );
      } else if (response.statusCode == 404) {
        return ApiResponse(
          success: false,
          message: 'Không tìm thấy thiết bị để cập nhật!',
          statusCode: 404,
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'Cập nhật thất bại (HTTP ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Lỗi kết nối máy chủ: $e',
        statusCode: 0,
      );
    }
  }

  // DELETE /api/ChildDeviceApi/{id}
  Future<ApiResponse<bool>> deleteDevice(int id) async {
    try {
      final headers = await _getAuthHeaders();
      final url = ApiConstants.childDevice(id);

      final response = await _client.delete(Uri.parse(url), headers: headers);

      if (response.statusCode == 204 || response.statusCode == 200) {
        return ApiResponse(
          success: true,
          data: true,
          message: 'Đã xóa thiết bị thành công!',
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 403) {
        return ApiResponse(
          success: false,
          message: 'Chỉ Admin hoặc phụ huynh sở hữu mới được xóa thiết bị!',
          statusCode: 403,
        );
      } else if (response.statusCode == 404) {
        return ApiResponse(
          success: false,
          message: 'Không tìm thấy thiết bị để xóa!',
          statusCode: 404,
        );
      } else {
        return ApiResponse(
          success: false,
          message: 'Xóa thiết bị thất bại (HTTP ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Lỗi kết nối máy chủ: $e',
        statusCode: 0,
      );
    }
  }

  // Quick action: Lock / Unlock device
  Future<ApiResponse<bool>> toggleLock(
    ChildDeviceModel device,
    bool isLocked,
  ) async {
    final dto = ChildDeviceUpsertDto(
      id: device.id,
      childName: device.childName,
      deviceName: device.deviceName,
      screenTimeLimitMinutes: device.screenTimeLimitMinutes,
      blockedApps: device.blockedApps,
      isLocked: isLocked,
      latitude: device.latitude,
      longitude: device.longitude,
      parentUsername: device.parentUsername,
      childUsername: device.childUsername,
      noiseThresholdDb: device.noiseThresholdDb,
    );
    return updateDevice(device.id, dto);
  }

  // PUT /api/ChildDeviceApi/{id}/location
  Future<ApiResponse<bool>> updateLocation(
    int id,
    double latitude,
    double longitude,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final url = ApiConstants.childDeviceLocation(id);
      final body = jsonEncode({'latitude': latitude, 'longitude': longitude});

      final response = await _client.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        return ApiResponse(
          success: true,
          data: true,
          message: 'Đã cập nhật vị trí GPS!',
          statusCode: 200,
        );
      }
      return ApiResponse(
        success: false,
        message: 'Lỗi cập nhật vị trí',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Lỗi kết nối: $e',
        statusCode: 0,
      );
    }
  }

  String _extractErrorMessage(List<int> bodyBytes, String defaultMsg) {
    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is Map<String, dynamic>) {
        if (decoded['Message'] != null) return decoded['Message'].toString();
        if (decoded['message'] != null) return decoded['message'].toString();
        if (decoded['errors'] != null && decoded['errors'] is Map) {
          final errs = decoded['errors'] as Map;
          final messages = <String>[];
          errs.forEach((k, v) {
            if (v is List && v.isNotEmpty) {
              messages.add(v.first.toString());
            }
          });
          if (messages.isNotEmpty) return messages.join('; ');
        }
        if (decoded['title'] != null) return decoded['title'].toString();
      }
    } catch (_) {}
    return defaultMsg;
  }
}
