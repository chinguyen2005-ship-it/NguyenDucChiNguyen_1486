import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/api_constants.dart';
import '../models/noise_model.dart';
import 'storage_service.dart';

class NoiseReportResult {
  final bool success;
  final String message;
  final bool isAlert;
  final bool parentNotifiedByEmail;
  final double? decibel;
  final double? thresholdDb;

  NoiseReportResult({
    required this.success,
    required this.message,
    this.isAlert = false,
    this.parentNotifiedByEmail = false,
    this.decibel,
    this.thresholdDb,
  });
}

class NoiseThresholdResult {
  final bool success;
  final String message;
  final double? thresholdDb;

  NoiseThresholdResult({
    required this.success,
    required this.message,
    this.thresholdDb,
  });
}

class NoiseReadingUpdate {
  final double currentDb;
  final double peakDb;
  final double meanDb;
  final bool isWarning;
  final bool isSimulated;

  NoiseReadingUpdate({
    required this.currentDb,
    required this.peakDb,
    required this.meanDb,
    required this.isWarning,
    this.isSimulated = false,
  });
}

class NoiseService {
  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  Timer? _simulatedTimer;

  bool _isMeasuring = false;
  bool get isMeasuring => _isMeasuring;

  bool _isSimulatedMode = false;
  bool get isSimulatedMode => _isSimulatedMode;

  double _peakDb = 0;
  final List<double> _readingsBuffer = [];
  DateTime? _sessionStartTime;

  Future<Map<String, String>> _authHeaders() async {
    final token = await StorageService.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Bắt đầu đo tiếng ồn từ Microphone
  /// Stream phát ra các giá trị cập nhật dB thời gian thực
  Stream<NoiseReadingUpdate> startMeasurement({
    double thresholdDb = 80.0,
    bool forceSimulation = false,
  }) {
    final controller = StreamController<NoiseReadingUpdate>();
    _isMeasuring = true;
    _peakDb = 0;
    _readingsBuffer.clear();
    _sessionStartTime = DateTime.now();

    void emitUpdate(double currentDb) {
      if (!_isMeasuring) return;
      _readingsBuffer.add(currentDb);
      if (currentDb > _peakDb) _peakDb = currentDb;

      final mean = _readingsBuffer.isEmpty
          ? currentDb
          : _readingsBuffer.reduce((a, b) => a + b) / _readingsBuffer.length;

      if (!controller.isClosed) {
        controller.add(
          NoiseReadingUpdate(
            currentDb: currentDb,
            peakDb: _peakDb,
            meanDb: mean,
            isWarning: currentDb >= thresholdDb,
            isSimulated: _isSimulatedMode,
          ),
        );
      }
    }

    if (forceSimulation || kIsWeb) {
      _isSimulatedMode = true;
      _startSimulation(emitUpdate);
      return controller.stream;
    }

    // Kiểm tra quyền microphone
    Permission.microphone.status.then((status) async {
      if (!status.isGranted) {
        final req = await Permission.microphone.request();
        if (!req.isGranted) {
          // Nếu không được cấp quyền microphone, chuyển sang chế độ mô phỏng với cảnh báo
          _isSimulatedMode = true;
          _startSimulation(emitUpdate);
          return;
        }
      }

      try {
        _isSimulatedMode = false;
        _noiseMeter = NoiseMeter();
        _noiseSubscription = _noiseMeter?.noise.listen(
          (NoiseReading reading) {
            _isSimulatedMode = false;
            // Giá trị dB thường nằm trong khoảng 0 - 120 dB
            final db = reading.meanDecibel.clamp(30.0, 130.0);
            emitUpdate(db);
          },
          onError: (Object error) {
            debugPrint('NoiseMeter error: $error. Falling back to simulation.');
            _isSimulatedMode = true;
            _startSimulation(emitUpdate);
          },
        );
      } catch (e) {
        debugPrint(
          'Cannot initialize NoiseMeter: $e. Falling back to simulation.',
        );
        _isSimulatedMode = true;
        _startSimulation(emitUpdate);
      }
    });

    controller.onCancel = () {
      stopMeasurement();
    };

    return controller.stream;
  }

  void _startSimulation(void Function(double) onValue) {
    _simulatedTimer?.cancel();
    final random = Random();
    double baseDb = 55.0;

    _simulatedTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      // Mô phỏng tiếng ồn môi trường tự nhiên (thỉnh thoảng có tiếng nói hoặc tiếng động lớn)
      final spike = random.nextDouble() < 0.15 ? random.nextDouble() * 35 : 0;
      final noise = (random.nextDouble() - 0.5) * 8;
      final current = (baseDb + noise + spike).clamp(35.0, 115.0);
      onValue(current);
    });
  }

  /// Dừng thu âm tiếng ồn
  void stopMeasurement() {
    _isMeasuring = false;
    _noiseSubscription?.cancel();
    _noiseSubscription = null;
    _simulatedTimer?.cancel();
    _simulatedTimer = null;
  }

  /// Lấy thông số phiên đo gần nhất để gửi lên server
  NoiseReadingDto? getLatestReading() {
    if (_readingsBuffer.isEmpty) return null;
    final average =
        _readingsBuffer.reduce((a, b) => a + b) / _readingsBuffer.length;
    final duration = _sessionStartTime != null
        ? DateTime.now().difference(_sessionStartTime!).inSeconds
        : 5;

    return NoiseReadingDto(
      decibel: double.parse(average.toStringAsFixed(1)),
      peakDecibel: double.parse(_peakDb.toStringAsFixed(1)),
      durationSeconds: max(1, duration),
      measuredAt: DateTime.now(),
    );
  }

  // ===================== API BACKEND INTEGRATION =====================

  /// Gửi dữ liệu đo tiếng ồn lên backend
  /// Backend: POST /api/ChildDeviceApi/{id}/noise
  Future<NoiseReportResult> reportNoise(
    int deviceId,
    NoiseReadingDto dto,
  ) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(ApiConstants.childDeviceNoise(deviceId));

      final response = await http
          .post(url, headers: headers, body: jsonEncode(dto.toJson()))
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic>? data;
      try {
        if (response.body.trim().isNotEmpty) {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) data = decoded;
        }
      } catch (_) {}

      if (response.statusCode == 200 && data?['status'] == true) {
        return NoiseReportResult(
          success: true,
          message: data?['message'] ?? 'Đã ghi nhận mức tiếng ồn.',
          isAlert: data?['isAlert'] == true,
          parentNotifiedByEmail: data?['parentNotifiedByEmail'] == true,
          decibel: (data?['decibel'] as num?)?.toDouble(),
          thresholdDb: (data?['thresholdDb'] as num?)?.toDouble(),
        );
      } else {
        return NoiseReportResult(
          success: false,
          message: data?['message'] ??
              'Không thể gửi dữ liệu tiếng ồn (Mã lỗi ${response.statusCode})',
        );
      }
    } on SocketException {
      return NoiseReportResult(
        success: false,
        message: 'Lỗi kết nối máy chủ backend. Vui lòng kiểm tra mạng.',
      );
    } catch (e) {
      return NoiseReportResult(
        success: false,
        message: 'Lỗi gửi dữ liệu tiếng ồn: $e',
      );
    }
  }

  /// Lấy lịch sử đo tiếng ồn của thiết bị
  /// Backend: GET /api/ChildDeviceApi/{id}/noise
  Future<NoiseHistoryModel?> getNoiseHistory(
    int deviceId, {
    DateTime? from,
    DateTime? to,
    bool alertsOnly = false,
    int take = 100,
  }) async {
    try {
      final headers = await _authHeaders();
      final query = <String, String>{
        'alertsOnly': alertsOnly.toString(),
        'take': take.toString(),
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
      };
      final uri = Uri.parse(ApiConstants.childDeviceNoise(deviceId))
          .replace(queryParameters: query);

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return NoiseHistoryModel.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching noise history: $e');
      return null;
    }
  }

  /// Lấy danh sách cảnh báo tiếng ồn chưa xem (Dành cho Phụ huynh / Admin)
  /// Backend: GET /api/ChildDeviceApi/noise-alerts
  Future<List<NoiseEventModel>> getUnacknowledgedAlerts({int take = 50}) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse('${ApiConstants.noiseAlerts}?take=$take');

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map(
              (json) => NoiseEventModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching unacknowledged alerts: $e');
      return [];
    }
  }

  /// Đánh dấu phụ huynh đã xem cảnh báo
  /// Backend: PUT /api/ChildDeviceApi/noise-alerts/{eventId}/ack
  Future<bool> acknowledgeAlert(int eventId) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(ApiConstants.acknowledgeNoiseAlert(eventId));

      final response = await http
          .put(url, headers: headers)
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error acknowledging alert: $e');
      return false;
    }
  }

  /// Cập nhật ngưỡng cảnh báo tiếng ồn (Chỉ dành cho Phụ huynh / Admin)
  /// Backend: PUT /api/ChildDeviceApi/{id}/noise-threshold
  Future<NoiseThresholdResult> updateNoiseThreshold(
    int deviceId,
    double thresholdDb,
  ) async {
    try {
      final headers = await _authHeaders();
      final url = Uri.parse(ApiConstants.childDeviceNoiseThreshold(deviceId));
      final response = await http
          .put(
            url,
            headers: headers,
            body: jsonEncode({'thresholdDb': thresholdDb}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 200 &&
          (data['status'] == true || data['Status'] == true)) {
        final newThreshold =
            ((data['noiseThresholdDb'] ??
                        data['NoiseThresholdDb'] ??
                        thresholdDb)
                    as num)
                .toDouble();
        return NoiseThresholdResult(
          success: true,
          message:
              data['message'] ??
              data['Message'] ??
              'Đã cập nhật ngưỡng cảnh báo.',
          thresholdDb: newThreshold,
        );
      } else if (response.statusCode == 403) {
        return NoiseThresholdResult(
          success: false,
          message:
              'Chỉ Phụ huynh hoặc Admin mới có quyền cập nhật ngưỡng tiếng ồn!',
        );
      } else {
        return NoiseThresholdResult(
          success: false,
          message:
              data['message'] ??
              data['Message'] ??
              'Lỗi cập nhật ngưỡng (Mã lỗi ${response.statusCode})',
        );
      }
    } on SocketException {
      return NoiseThresholdResult(
        success: false,
        message: 'Lỗi kết nối máy chủ backend.',
      );
    } catch (e) {
      return NoiseThresholdResult(
        success: false,
        message: 'Lỗi cập nhật ngưỡng: $e',
      );
    }
  }
}
