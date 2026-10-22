import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenducchinguyen_1486/models/auth_models.dart';
import 'package:nguyenducchinguyen_1486/models/device_model.dart';
import 'package:nguyenducchinguyen_1486/models/noise_model.dart';
import 'package:nguyenducchinguyen_1486/screens/device/device_detail_screen.dart';
import 'package:nguyenducchinguyen_1486/screens/noise/noise_meter_screen.dart';
import 'package:nguyenducchinguyen_1486/services/noise_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'test_parent_jwt_token',
      'user_profile': '{"id":"parent-uuid-001","username":"parent1","email":"parent1@kidguard.vn","fullName":"Nguyen Duc Chi Nguyen","roles":["Parent"],"emailConfirmed":true,"hasFace":false}',
    });
  });

  final testParentUser = UserProfile(
    id: 'parent-uuid-001',
    username: 'parent1',
    email: 'parent1@kidguard.vn',
    fullName: 'Nguyen Duc Chi Nguyen',
    roles: ['Parent'],
    hasFace: false,
    emailConfirmed: true,
  );

  final testChildUser = UserProfile(
    id: 'child-uuid-002',
    username: 'be_bap',
    email: 'bebap@kidguard.vn',
    fullName: 'Bé Bắp',
    roles: ['Child'],
    hasFace: false,
    emailConfirmed: true,
  );

  final testDevice = ChildDeviceModel(
    id: 10,
    childName: 'Bé Bắp',
    deviceName: 'Samsung Galaxy Tab A9',
    screenTimeLimitMinutes: 120,
    blockedApps: 'TikTok, YouTube',
    isLocked: false,
    latitude: 10.762622,
    longitude: 106.660172,
    parentUsername: 'parent1',
    childUsername: 'be_bap',
    noiseThresholdDb: 75.0,
    lastNoiseDb: 68.5,
    lastUpdated: DateTime(2026, 10, 22, 10, 0),
  );

  group('Task 04.4: Model & Service Logic Tests', () {
    test(
      'NoiseThresholdResult models success and updated threshold correctly',
      () {
        final res = NoiseThresholdResult(
          success: true,
          message: 'Đã đặt ngưỡng cảnh báo tiếng ồn 80 dB.',
          thresholdDb: 80.0,
        );

        expect(res.success, isTrue);
        expect(res.thresholdDb, 80.0);
        expect(res.message, contains('80 dB'));
      },
    );

    test(
      'NoiseHistoryModel correctly parses telemetry stats and breach alerts',
      () {
        final json = {
          'deviceId': 10,
          'childName': 'Bé Bắp',
          'noiseThresholdDb': 75.0,
          'lastNoiseDb': 82.5,
          'count': 3,
          'alertCount': 1,
          'averageDb': 71.3,
          'maxDb': 82.5,
          'events': [
            {
              'id': 101,
              'childDeviceId': 10,
              'decibel': 65.0,
              'thresholdDb': 75.0,
              'isAlert': false,
              'isAcknowledged': false,
              'durationSeconds': 5,
              'measuredAt': '2026-10-22T08:00:00Z',
            },
            {
              'id': 102,
              'childDeviceId': 10,
              'decibel': 82.5,
              'thresholdDb': 75.0,
              'isAlert': true,
              'isAcknowledged': false,
              'durationSeconds': 10,
              'measuredAt': '2026-10-22T08:30:00Z',
            },
          ],
        };

        final history = NoiseHistoryModel.fromJson(json);

        expect(history.deviceId, 10);
        expect(history.noiseThresholdDb, 75.0);
        expect(history.count, 3);
        expect(history.alertCount, 1);
        expect(history.averageDb, 71.3);
        expect(history.maxDb, 82.5);
        expect(history.events.length, 2);
        expect(history.events[1].isAlert, isTrue);
        expect(history.events[1].decibel, 82.5);
      },
    );

    test(
      'NoiseService start and stop measurement manages lifecycle cleanly',
      () {
        final service = NoiseService();

        expect(service.isMeasuring, isFalse);

        final stream = service.startMeasurement(
          thresholdDb: 75.0,
          forceSimulation: true,
        );

        expect(stream, isNotNull);
        expect(service.isMeasuring, isTrue);
        expect(service.isSimulatedMode, isTrue);

        // Stop measurement
        service.stopMeasurement();
        expect(service.isMeasuring, isFalse);
      },
    );
  });

  group('Task 04.4: Role-Based Noise Control in NoiseMeterScreen', () {
    testWidgets(
      'Parent view allows editing threshold and shows parent controls',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: NoiseMeterScreen(device: testDevice, isParentViewer: true),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Đo Tiếng Ồn Môi Trường'), findsOneWidget);
        expect(find.text('Bé Bắp — Samsung Galaxy Tab A9'), findsOneWidget);
        expect(find.text('Ngưỡng cảnh báo: 75 dB'), findsOneWidget);
        expect(
          find.byIcon(Icons.tune_rounded),
          findsOneWidget,
        ); // Edit button for parent
        expect(find.text('Chỉ đọc'), findsNothing); // Not locked for parent
      },
    );

    testWidgets(
      'Child view locks threshold as Read-Only and shows privacy disclosure',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: NoiseMeterScreen(device: testDevice, isParentViewer: false),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Đo Tiếng Ồn Môi Trường'), findsOneWidget);
        expect(find.text('Chỉ đọc'), findsOneWidget); // Locked badge for Child
        expect(
          find.byIcon(Icons.tune_rounded),
          findsNothing,
        ); // No edit button for child
        expect(
          find.textContaining('Quyền Microphone'),
          findsOneWidget,
        ); // Privacy transparency
        expect(find.textContaining('không nghe lén'), findsOneWidget);
      },
    );
  });

  group('Task 04.4: DeviceDetailScreen Parent-Controlled Noise Hub', () {
    testWidgets(
      'Renders Parent-Controlled Noise section with BLOCKED remote badge and threshold edit',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DeviceDetailScreen(
              device: testDevice,
              currentUser: testParentUser,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Check section header
        expect(
          find.text('Giám Sát Tiếng Ồn (Parent-Controlled)'),
          findsOneWidget,
        );

        // Check applied threshold
        expect(find.text('75 dB'), findsWidgets);
        expect(find.text('Phụ huynh'), findsOneWidget);
        expect(find.text('Đổi'), findsOneWidget); // Quick edit button

        // Check Remote Request Blocked Status
        expect(find.text('REMOTE REQUEST: BLOCKED'), findsOneWidget);
        expect(
          find.textContaining(
            'Backend chưa có kênh truyền lệnh thời gian thực',
          ),
          findsOneWidget,
        );
        expect(find.text('Yêu Cầu Đo Từ Xa (Chưa khả dụng)'), findsOneWidget);

        // Tapping blocked button opens technical explanation modal
        await tester.ensureVisible(
          find.text('Yêu Cầu Đo Từ Xa (Chưa khả dụng)'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Yêu Cầu Đo Từ Xa (Chưa khả dụng)'));
        await tester.pumpAndSettle();

        expect(find.text('Trạng Thái: Yêu Cầu Đo Từ Xa'), findsOneWidget);
        expect(find.textContaining('Kiến trúc Backend'), findsOneWidget);
        expect(
          find.textContaining('FCM Push Notification hoặc SignalR Hub'),
          findsOneWidget,
        );
        expect(
          find.textContaining('KHÔNG tự động bật microphone bí mật'),
          findsOneWidget,
        );

        // Dismiss dialog
        await tester.tap(find.text('Đã hiểu'));
        await tester.pumpAndSettle();
        expect(find.text('Trạng Thái: Yêu Cầu Đo Từ Xa'), findsNothing);
      },
    );

    testWidgets(
      'Child user sees Read-Only noise section without threshold change button',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: DeviceDetailScreen(
              device: testDevice,
              currentUser: testChildUser,
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.text('Giám Sát Tiếng Ồn (Parent-Controlled)'),
          findsOneWidget,
        );
        expect(find.text('Chỉ xem'), findsOneWidget);
        expect(find.text('Đổi'), findsNothing); // Child cannot edit threshold
      },
    );
  });

  group('Task 04.4: Multi-Viewport Responsive Tests', () {
    final viewports = [
      {'name': '320x640 Compact Phone', 'width': 320.0, 'height': 640.0},
      {'name': '360x800 Standard Phone', 'width': 360.0, 'height': 800.0},
      {'name': '393x852 iPhone 15 Class', 'width': 393.0, 'height': 852.0},
      {'name': '430x932 Large Phone', 'width': 430.0, 'height': 932.0},
    ];

    for (final vp in viewports) {
      testWidgets(
        'DeviceDetailScreen renders cleanly on ${vp['name']} at font scale 1.0 & 1.3',
        (tester) async {
          final w = vp['width'] as double;
          final h = vp['height'] as double;

          for (final scale in [1.0, 1.3]) {
            tester.view.physicalSize = Size(w * 3.0, h * 3.0);
            tester.view.devicePixelRatio = 3.0;

            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(fontFamily: 'Inter'),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(w, h),
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: DeviceDetailScreen(
                    device: testDevice,
                    currentUser: testParentUser,
                  ),
                ),
              ),
            );

            await tester.pumpAndSettle();

            expect(find.byType(DeviceDetailScreen), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: 'No RenderFlex overflow on ${vp['name']} at scale $scale',
            );
          }

          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        },
      );
    }
  });
}
