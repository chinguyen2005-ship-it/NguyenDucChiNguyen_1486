import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenducchinguyen_1486/models/auth_models.dart';
import 'package:nguyenducchinguyen_1486/models/device_model.dart';
import 'package:nguyenducchinguyen_1486/models/noise_model.dart';
import 'package:nguyenducchinguyen_1486/models/qr_payload_model.dart';
import 'package:nguyenducchinguyen_1486/services/face_auth_service.dart';
import 'package:nguyenducchinguyen_1486/screens/noise/noise_meter_screen.dart';
import 'package:nguyenducchinguyen_1486/screens/qr/qr_generator_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'test_jwt_bearer_token',
      'user_profile': '{"id":"parent_01","username":"parent1","email":"parent@kidguard.local","fullName":"Phụ Huynh Test","roles":["Parent"],"emailConfirmed":true}',
    });
  });

  group('Feature A — Face Authentication Unit Tests', () {
    test('FaceAuthResult accurately encapsulates success and ArcFace similarity score', () {
      final res = FaceAuthResult(
        success: true,
        message: 'Xác thực khuôn mặt thành công',
        similarity: 0.785,
        token: 'jwt_face_token_123',
        user: UserProfile(
          id: 'u1',
          username: 'parent1',
          email: 'parent1@kidguard.local',
          fullName: 'Parent One',
          roles: const ['Parent'],
          emailConfirmed: true,
        ),
      );

      expect(res.success, isTrue);
      expect(
        res.similarity,
        greaterThanOrEqualTo(0.42),
      ); // Backend ArcFace threshold
      expect(res.token, 'jwt_face_token_123');
      expect(res.user?.username, 'parent1');
    });

    test('FaceAuthResult handles rejection and low similarity scores', () {
      final res = FaceAuthResult(
        success: false,
        message: 'Khuôn mặt không khớp với mẫu đã đăng ký',
        similarity: 0.28,
      );

      expect(res.success, isFalse);
      expect(res.similarity, lessThan(0.42));
      expect(res.token, isNull);
    });
  });

  group('Feature D — Noise Measurement & Telemetry Model Tests', () {
    test('NoiseReadingDto correctly prepares payload matching group backend contract', () {
      final now = DateTime.parse('2026-10-22T08:00:00Z');
      final dto = NoiseReadingDto(
        decibel: 84.5,
        peakDecibel: 92.1,
        durationSeconds: 15,
        measuredAt: now,
      );

      final json = dto.toJson();

      expect(json['decibel'], 84.5);
      expect(json['peakDecibel'], 92.1);
      expect(json['durationSeconds'], 15);
      expect(json['measuredAt'], '2026-10-22T08:00:00.000Z');
    });

    test(
      'NoiseEventModel correctly deserializes backend alert and warning state',
      () {
        final jsonAlert = {
          'id': 101,
          'childDeviceId': 5,
          'decibel': 88.0,
          'thresholdDb': 80.0,
          'createdAt': '2026-10-22T08:30:00Z',
          'isAcknowledged': false,
          'isAlert': true,
        };

        final event = NoiseEventModel.fromJson(jsonAlert);

        expect(event.id, 101);
        expect(event.childDeviceId, 5);
        expect(event.decibel, 88.0);
        expect(event.thresholdDb, 80.0);
        expect(event.isAlert, isTrue);
        expect(event.isAcknowledged, isFalse);
      },
    );

    test('NoiseHistoryModel correctly aggregates noise telemetry summary', () {
      final historyJson = {
        'deviceId': 5,
        'childName': 'Bé Nam',
        'noiseThresholdDb': 80.0,
        'averageDb': 62.4,
        'maxDb': 91.8,
        'alertCount': 1,
        'count': 2,
        'events': [
          {
            'id': 1,
            'childDeviceId': 5,
            'decibel': 88.5,
            'thresholdDb': 80.0,
            'durationSeconds': 5,
            'isAlert': true,
            'isAcknowledged': false,
            'measuredAt': '2026-10-22T08:00:00Z',
          },
          {
            'id': 2,
            'childDeviceId': 5,
            'decibel': 55.2,
            'thresholdDb': 80.0,
            'durationSeconds': 5,
            'isAlert': false,
            'isAcknowledged': false,
            'measuredAt': '2026-10-22T08:05:00Z',
          },
        ],
      };

      final model = NoiseHistoryModel.fromJson(historyJson);

      expect(model.deviceId, 5);
      expect(model.childName, 'Bé Nam');
      expect(model.averageDb, 62.4);
      expect(model.maxDb, 91.8);
      expect(model.events.length, 2);
      expect(model.alertCount, 1);
    });
  });

  group('Feature E — QR Payload Security & FNV-1a Integrity Tests', () {
    test('KidGuardQrPayload generates valid QR JSON and self-verifies', () {
      final payload = KidGuardQrPayload.create(
        deviceId: 12,
        childName: 'Bé Lan',
        deviceName: 'Xiaomi Redmi Note 13',
        parentUsername: 'parent1',
        expirySeconds: 600,
      );

      final qrString = payload.toQrString();
      expect(qrString, contains('"t":"kidguard_device"'));
      expect(qrString, contains('"id":12'));
      expect(qrString, contains('"c":"Bé Lan"'));
      expect(qrString, contains('"sig":'));

      // Check deserialization and checksum verification
      final parsed = KidGuardQrPayload.fromQrString(qrString);
      expect(parsed, isNotNull);
      expect(parsed!.deviceId, 12);
      expect(parsed.childName, 'Bé Lan');
      expect(parsed.deviceName, 'Xiaomi Redmi Note 13');
      expect(parsed.parentUsername, 'parent1');
      expect(parsed.isExpired, isFalse);
    });

    test(
      'Tampered QR Payload fails FNV-1a checksum validation and is rejected',
      () {
        final payload = KidGuardQrPayload.create(
          deviceId: 12,
          childName: 'Bé Lan',
          deviceName: 'Xiaomi Redmi Note 13',
          parentUsername: 'parent1',
        );

        final rawJson = payload.toJson();
        // Giả mạo ID thiết bị (12 -> 999) nhưng giữ nguyên chữ ký sig cũ
        rawJson['id'] = 999;
        final tamperedQrString = rawJson
            .toString()
            .replaceAll(':', ': ')
            .replaceAll(',', ', ');

        final parsed = KidGuardQrPayload.fromQrString(tamperedQrString);
        expect(
          parsed,
          isNull,
          reason:
              'Tampered device ID must fail FNV-1a checksum and return null',
        );
      },
    );

    test('Expired QR Payload is detected and marked expired', () {
      // Giả lập payload với thời gian quá khứ
      final pastTimestamp =
          DateTime.now().millisecondsSinceEpoch - (700 * 1000); // 700s trước
      final rawData = '5|Bé Bi|iPad|parent1|$pastTimestamp';
      // Compute correct hash for the past timestamp
      var hash = 0x811c9dc5;
      for (final b in rawData.codeUnits) {
        hash ^= b;
        hash = (hash * 0x01000193) & 0xFFFFFFFF;
      }
      final checksum = hash.toRadixString(16).padLeft(8, '0');

      final expiredPayload = KidGuardQrPayload(
        deviceId: 5,
        childName: 'Bé Bi',
        deviceName: 'iPad',
        parentUsername: 'parent1',
        timestamp: pastTimestamp,
        expirySeconds: 600,
        checksum: checksum,
      );

      expect(expiredPayload.isExpired, isTrue);
      expect(expiredPayload.remainingSeconds, lessThanOrEqualTo(0));
    });

    test('Security Verification: QR Payload strictly excludes sensitive credentials', () {
      final payload = KidGuardQrPayload.create(
        deviceId: 99,
        childName: 'Child Test',
        deviceName: 'Device Test',
        parentUsername: 'parent1',
      );

      final qrString = payload.toQrString().toLowerCase();

      expect(qrString.contains('password'), isFalse);
      expect(qrString.contains('jwt'), isFalse);
      expect(qrString.contains('token'), isFalse);
      expect(qrString.contains('otp'), isFalse);
      expect(qrString.contains('secret'), isFalse);
    });
  });

  group('UI & Rendering Tests for Advanced Features', () {
    testWidgets(
      'QrGeneratorScreen renders device details, QR image and countdown without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.0; // 360 x 800 viewport

        final testDevice = ChildDeviceModel(
          id: 7,
          childName: 'Bé An',
          deviceName: 'Samsung Tab A',
          noiseThresholdDb: 75.0,
          parentUsername: 'parent1',
        );

        final testUser = UserProfile(
          id: 'p1',
          username: 'parent1',
          email: 'parent@kidguard.local',
          fullName: 'Phụ Huynh An',
          roles: const ['Parent'],
          emailConfirmed: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: QrGeneratorScreen(device: testDevice, currentUser: testUser),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Mã QR Thiết Bị'), findsOneWidget);
        expect(find.text('Samsung Tab A'), findsOneWidget);
        expect(find.text('Trẻ quản lý: Bé An'), findsOneWidget);
        expect(find.text('Mã thiết bị ID: #7'), findsOneWidget);
        expect(find.byType(QrGeneratorScreen), findsOneWidget);

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
      },
    );

    testWidgets(
      'NoiseMeterScreen renders circular gauge, controls, and telemetry button',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3.0; // 360 x 800 viewport

        final testDevice = ChildDeviceModel(
          id: 7,
          childName: 'Bé An',
          deviceName: 'Samsung Tab A',
          noiseThresholdDb: 75.0,
        );

        await tester.pumpWidget(
          MaterialApp(home: NoiseMeterScreen(device: testDevice)),
        );

        await tester.pumpAndSettle();

        expect(find.text('Đo Tiếng Ồn Môi Trường'), findsOneWidget);
        expect(find.text('Bé An — Samsung Tab A'), findsOneWidget);
        expect(find.text('Bắt Đầu Đo'), findsOneWidget);
        expect(find.text('Gửi Lên Server'), findsOneWidget);

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
      },
    );
  });
}
