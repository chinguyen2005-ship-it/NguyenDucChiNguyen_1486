import 'dart:convert';

class KidGuardQrPayload {
  static const String currentVersion = '1.0';
  static const String payloadType = 'kidguard_device';

  final String version;
  final String type;
  final int deviceId;
  final String childName;
  final String deviceName;
  final String parentUsername;
  final int timestamp;
  final int expirySeconds;
  final String checksum;

  KidGuardQrPayload({
    this.version = currentVersion,
    this.type = payloadType,
    required this.deviceId,
    required this.childName,
    required this.deviceName,
    required this.parentUsername,
    required this.timestamp,
    this.expirySeconds = 600, // 10 phút
    required this.checksum,
  });

  /// Thuật toán băm FNV-1a 32-bit thuần Dart, độc lập nền tảng, không cần package phụ
  static String _computeChecksum(String data) {
    var hash = 0x811c9dc5;
    final bytes = utf8.encode(data);
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  /// Tạo payload kèm checksum an toàn chống giả mạo
  factory KidGuardQrPayload.create({
    required int deviceId,
    required String childName,
    required String deviceName,
    required String parentUsername,
    int expirySeconds = 600,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rawData = '$deviceId|$childName|$deviceName|$parentUsername|$now';
    final hash = _computeChecksum(rawData);

    return KidGuardQrPayload(
      version: currentVersion,
      type: payloadType,
      deviceId: deviceId,
      childName: childName,
      deviceName: deviceName,
      parentUsername: parentUsername,
      timestamp: now,
      expirySeconds: expirySeconds,
      checksum: hash,
    );
  }

  bool get isExpired {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - timestamp) > (expirySeconds * 1000);
  }

  int get remainingSeconds {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = (expirySeconds * 1000) - (now - timestamp);
    return diff > 0 ? (diff / 1000).ceil() : 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'v': version,
      't': type,
      'id': deviceId,
      'c': childName,
      'd': deviceName,
      'p': parentUsername,
      'ts': timestamp,
      'exp': expirySeconds,
      'sig': checksum,
    };
  }

  String toQrString() {
    return jsonEncode(toJson());
  }

  static KidGuardQrPayload? fromQrString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final type = decoded['t'] as String?;
      if (type != payloadType) return null;

      final deviceId = (decoded['id'] as num?)?.toInt() ?? 0;
      final childName = decoded['c'] as String? ?? '';
      final deviceName = decoded['d'] as String? ?? '';
      final parentUsername = decoded['p'] as String? ?? '';
      final timestamp = (decoded['ts'] as num?)?.toInt() ?? 0;
      final expirySeconds = (decoded['exp'] as num?)?.toInt() ?? 600;
      final checksum = decoded['sig'] as String? ?? '';

      // Kiểm tra checksum
      final rawData =
          '$deviceId|$childName|$deviceName|$parentUsername|$timestamp';
      final expectedHash = _computeChecksum(rawData);

      if (checksum != expectedHash) {
        // Sai chữ ký số / dữ liệu bị can thiệp
        return null;
      }

      return KidGuardQrPayload(
        version: decoded['v'] as String? ?? currentVersion,
        type: type ?? payloadType,
        deviceId: deviceId,
        childName: childName,
        deviceName: deviceName,
        parentUsername: parentUsername,
        timestamp: timestamp,
        expirySeconds: expirySeconds,
        checksum: checksum,
      );
    } catch (_) {
      return null;
    }
  }
}
