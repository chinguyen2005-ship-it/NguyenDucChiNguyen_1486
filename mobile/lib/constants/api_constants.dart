import 'dart:io';

import 'package:flutter/foundation.dart';

class ApiConstants {
  // Cloud Deployed Backend (nhom13 trên IIS / SmarterASP.NET)
  static const String cloudBaseUrl =
      'https://nhiemhotdcm-001-site1.htempurl.com';

  // Chế độ ưu tiên: BẬT kết nối Server Cloud Deployed
  static const bool useCloudServer = true;

  // Cấu hình cục bộ (Local fallback) khi chạy offline / máy ảo
  static const int httpPort = 5221;
  static const int httpsPort = 7092;
  static const String serverHost = '127.0.0.1';
  static const bool useHttps = true;

  static String get baseUrl {
    if (useCloudServer) {
      return cloudBaseUrl;
    }

    final scheme = useHttps ? 'https' : 'http';
    final port = useHttps ? httpsPort : httpPort;

    if (kIsWeb) return '$scheme://localhost:$port';
    try {
      if (Platform.isAndroid) {
        return '$scheme://$serverHost:$port';
      }
    } catch (_) {}
    return '$scheme://localhost:$port';
  }

  // AuthenticateController endpoints in Group Backend (nhom13)
  static String get register => '$baseUrl/api/Authenticate/register';
  static String get confirmEmail => '$baseUrl/api/Authenticate/confirm-email';
  static String get resendConfirmation =>
      '$baseUrl/api/Authenticate/resend-confirmation';
  static String get login => '$baseUrl/api/Authenticate/login';
  static String get verifyOtp => '$baseUrl/api/Authenticate/verify-otp';
  static String get me => '$baseUrl/api/Authenticate/me';

  static String get registerFace => '$baseUrl/api/Authenticate/register-face';
  static String get deleteFace => '$baseUrl/api/Authenticate/face';
  static String get loginFace => '$baseUrl/api/Authenticate/login-face';

  // Role-protected endpoints for live authorization verification
  static String get adminUsers => '$baseUrl/api/Admin/users';
  static String get childDevices => '$baseUrl/api/ChildDeviceApi';
  static String get adminOnly => adminUsers;
  static String get parentOnly => childDevices;
  static String get childOnly => childDevices;

  static String childDevice(int id) => '$baseUrl/api/ChildDeviceApi/$id';
  static String childDeviceLocation(int id) =>
      '$baseUrl/api/ChildDeviceApi/$id/location';
  static String childDeviceNoise(int id) =>
      '$baseUrl/api/ChildDeviceApi/$id/noise';
  static String childDeviceNoiseThreshold(int id) =>
      '$baseUrl/api/ChildDeviceApi/$id/noise-threshold';
  static String get noiseAlerts => '$baseUrl/api/ChildDeviceApi/noise-alerts';
  static String acknowledgeNoiseAlert(int id) =>
      '$baseUrl/api/ChildDeviceApi/noise-alerts/$id/ack';

  // Admin user management endpoints
  static String adminSetRole(String username) =>
      '$baseUrl/api/Admin/users/$username/role';
  static String adminUnlockUser(String username) =>
      '$baseUrl/api/Admin/users/$username/unlock';
}
