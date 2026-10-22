import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenducchinguyen_1486/models/auth_models.dart';
import 'package:nguyenducchinguyen_1486/models/device_model.dart';
import 'package:nguyenducchinguyen_1486/models/noise_model.dart';
import 'package:nguyenducchinguyen_1486/screens/safety/family_safety_insights_screen.dart';
import 'package:nguyenducchinguyen_1486/services/device_service.dart';
import 'package:nguyenducchinguyen_1486/services/noise_service.dart';

class FakeDeviceService extends DeviceService {
  final ApiResponse<List<ChildDeviceModel>> response;
  FakeDeviceService(this.response);

  @override
  Future<ApiResponse<List<ChildDeviceModel>>> getDevices({
    String? search,
  }) async => response;
}

class FakeNoiseService extends NoiseService {
  final List<NoiseEventModel> alerts;
  final Map<int, NoiseHistoryModel> histories;
  final bool ackSuccess;
  int ackCallCount = 0;

  FakeNoiseService({
    this.alerts = const [],
    this.histories = const {},
    this.ackSuccess = true,
  });

  @override
  Future<List<NoiseEventModel>> getUnacknowledgedAlerts({
    int take = 100,
  }) async => alerts;

  @override
  Future<NoiseHistoryModel?> getNoiseHistory(
    int deviceId, {
    DateTime? from,
    DateTime? to,
    bool alertsOnly = false,
    int take = 100,
  }) async {
    return histories[deviceId];
  }

  @override
  Future<bool> acknowledgeAlert(int eventId) async {
    ackCallCount++;
    return ackSuccess;
  }
}

ApiResponse<List<ChildDeviceModel>> apiSuccess(List<ChildDeviceModel> data) =>
    ApiResponse(success: true, data: data, message: 'OK', statusCode: 200);

ApiResponse<List<ChildDeviceModel>> apiError(String msg) =>
    ApiResponse(success: false, message: msg, statusCode: 500);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'test_parent_jwt_token',
      'user_profile': '{"id":"parent-001","username":"parent1","email":"parent1@kidguard.vn","fullName":"Nguyen Duc Chi Nguyen","roles":["Parent"],"emailConfirmed":true,"hasFace":false}',
    });
  });

  final testParentUser = UserProfile(
    id: 'parent-001',
    username: 'parent1',
    email: 'parent1@kidguard.vn',
    fullName: 'Nguyen Duc Chi Nguyen',
    roles: ['Parent'],
    hasFace: false,
    emailConfirmed: true,
  );

  final testChildUser = UserProfile(
    id: 'child-002',
    username: 'be_bap',
    email: 'bebap@kidguard.vn',
    fullName: 'Bé Bắp',
    roles: ['Child'],
    hasFace: false,
    emailConfirmed: true,
  );

  final testDevice1 = ChildDeviceModel(
    id: 10,
    childName: 'Bé Bắp',
    deviceName: 'Samsung Tab A9',
    screenTimeLimitMinutes: 120,
    blockedApps: 'TikTok',
    isLocked: false,
    latitude: 10.762622,
    longitude: 106.660172,
    parentUsername: 'parent1',
    childUsername: 'be_bap',
    noiseThresholdDb: 75.0,
    lastNoiseDb: 68.0,
    lastUpdated: DateTime(2026, 10, 22, 10, 0),
  );

  final testDevice2 = ChildDeviceModel(
    id: 11,
    childName: 'Bé Bo',
    deviceName: 'iPad Mini',
    screenTimeLimitMinutes: 90,
    blockedApps: 'YouTube',
    isLocked: true,
    latitude: 10.762622,
    longitude: 106.660172,
    parentUsername: 'parent1',
    childUsername: 'be_bo',
    noiseThresholdDb: 70.0,
    lastNoiseDb: 82.0,
    lastUpdated: DateTime(2026, 10, 22, 11, 0),
  );

  final now = DateTime.now();

  final testAlert1 = NoiseEventModel(
    id: 201,
    childDeviceId: 10,
    decibel: 84.5,
    thresholdDb: 75.0,
    isAlert: true,
    isAcknowledged: false,
    durationSeconds: 15,
    measuredAt: now.subtract(const Duration(hours: 2)),
    childName: 'Bé Bắp',
    deviceName: 'Samsung Tab A9',
  );

  final testAlert2 = NoiseEventModel(
    id: 202,
    childDeviceId: 11,
    decibel: 81.0,
    thresholdDb: 70.0,
    isAlert: true,
    isAcknowledged: false,
    durationSeconds: 10,
    measuredAt: now.subtract(const Duration(hours: 5)),
    childName: 'Bé Bo',
    deviceName: 'iPad Mini',
  );

  final testHistory1 = NoiseHistoryModel(
    deviceId: 10,
    childName: 'Bé Bắp',
    noiseThresholdDb: 75.0,
    lastNoiseDb: 68.0,
    count: 2,
    alertCount: 1,
    averageDb: 72.0,
    maxDb: 84.5,
    events: [testAlert1],
  );

  final testHistory2 = NoiseHistoryModel(
    deviceId: 11,
    childName: 'Bé Bo',
    noiseThresholdDb: 70.0,
    lastNoiseDb: 82.0,
    count: 2,
    alertCount: 1,
    averageDb: 76.5,
    maxDb: 81.0,
    events: [testAlert2],
  );

  Widget createSubject({
    required UserProfile user,
    DeviceService? deviceService,
    NoiseService? noiseService,
  }) {
    return MaterialApp(
      home: FamilySafetyInsightsScreen(
        currentUser: user,
        deviceService: deviceService,
        noiseService: noiseService,
      ),
    );
  }

  group('TASK 05.2: Role Authorization Tests', () {
    testWidgets('TC01: Parent can open Safety Insights screen successfully', (
      tester,
    ) async {
      final fakeDevService = FakeDeviceService(
        apiSuccess([testDevice1, testDevice2]),
      );
      final fakeNoiseService = FakeNoiseService(
        alerts: [testAlert1, testAlert2],
        histories: {10: testHistory1, 11: testHistory2},
      );

      await tester.pumpWidget(
        createSubject(
          user: testParentUser,
          deviceService: fakeDevService,
          noiseService: fakeNoiseService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Góc An Toàn Gia Đình'), findsOneWidget);
      expect(
        find.text('Thông tin an toàn từ thiết bị của con'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      expect(find.text('Tổng thiết bị'), findsOneWidget);
    });

    testWidgets('TC02: Child is denied access to Safety Insights screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        createSubject(
          user: testChildUser,
          deviceService: FakeDeviceService(apiSuccess([])),
          noiseService: FakeNoiseService(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Truy Cập Bị Từ Chối'), findsOneWidget);
      expect(
        find.textContaining('chỉ dành riêng cho tài khoản Phụ huynh'),
        findsOneWidget,
      );
      expect(find.text('Quay Lại Dashboard'), findsOneWidget);
      expect(find.text('Tổng thiết bị'), findsNothing);
    });
  });

  group('TASK 05.2: Data Aggregation & Filter Tests', () {
    testWidgets(
      'TC03 & TC05: Displays accurate overview counts from backend API',
      (tester) async {
        final fakeDevService = FakeDeviceService(
          apiSuccess([testDevice1, testDevice2]),
        );
        final fakeNoiseService = FakeNoiseService(
          alerts: [testAlert1, testAlert2],
          histories: {10: testHistory1, 11: testHistory2},
        );

        await tester.pumpWidget(
          createSubject(
            user: testParentUser,
            deviceService: fakeDevService,
            noiseService: fakeNoiseService,
          ),
        );
        await tester.pumpAndSettle();

        // Total devices: 2
        expect(find.text('Tổng thiết bị'), findsOneWidget);
        expect(find.text('2'), findsWidgets);
        // Marked locked: 1 (testDevice2 isLocked == true)
        expect(find.text('Đang khóa (DB)'), findsOneWidget);
        expect(find.text('1'), findsWidgets);
        // Active unacknowledged alerts: 2
        expect(find.text('Chưa xác nhận'), findsOneWidget);
      },
    );

    testWidgets('TC04: Filters data by specific child device', (tester) async {
      final fakeDevService = FakeDeviceService(
        apiSuccess([testDevice1, testDevice2]),
      );
      final fakeNoiseService = FakeNoiseService(
        alerts: [testAlert1, testAlert2],
        histories: {10: testHistory1, 11: testHistory2},
      );

      await tester.pumpWidget(
        createSubject(
          user: testParentUser,
          deviceService: fakeDevService,
          noiseService: fakeNoiseService,
        ),
      );
      await tester.pumpAndSettle();

      // Tap Device 10 FilterChip (Bé Bắp)
      final device10Chip = find.widgetWithText(
        FilterChip,
        'Bé Bắp (Samsung Tab A9)',
      );
      expect(device10Chip, findsOneWidget);
      await tester.tap(device10Chip);
      await tester.pumpAndSettle();

      // Device 10 has 0 locked devices
      expect(find.text('Bình thường'), findsOneWidget);
    });

    testWidgets(
      'TC06: In-place alert acknowledgment calls API and updates count',
      (tester) async {
        final fakeDevService = FakeDeviceService(apiSuccess([testDevice1]));
        final fakeNoiseService = FakeNoiseService(
          alerts: [testAlert1],
          histories: {10: testHistory1},
          ackSuccess: true,
        );

        await tester.pumpWidget(
          createSubject(
            user: testParentUser,
            deviceService: fakeDevService,
            noiseService: fakeNoiseService,
          ),
        );
        await tester.pumpAndSettle();

        final ackFinder = find.text('Xác nhận đã xem');
        await tester.scrollUntilVisible(
          ackFinder,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(ackFinder, findsOneWidget);
        await tester.tap(ackFinder);
        await tester.pumpAndSettle();

        expect(fakeNoiseService.ackCallCount, 1);
      },
    );
  });

  group('TASK 05.2: Empty & Error State Tests', () {
    testWidgets(
      'TC07: Trend Analysis shows empty state when no breach data exists',
      (tester) async {
        final fakeDevService = FakeDeviceService(apiSuccess([testDevice1]));
        final emptyHistory = NoiseHistoryModel(
          deviceId: 10,
          childName: 'Bé Bắp',
          noiseThresholdDb: 75.0,
          lastNoiseDb: 60.0,
          count: 1,
          alertCount: 0,
          averageDb: 60.0,
          maxDb: 60.0,
          events: [],
        );
        final fakeNoiseService = FakeNoiseService(
          alerts: [],
          histories: {10: emptyHistory},
        );

        await tester.pumpWidget(
          createSubject(
            user: testParentUser,
            deviceService: fakeDevService,
            noiseService: fakeNoiseService,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Chưa đủ dữ liệu để phân tích xu hướng'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TC08: Noise alerts section displays empty state when 0 alerts exist',
      (tester) async {
        final fakeDevService = FakeDeviceService(apiSuccess([testDevice1]));
        final fakeNoiseService = FakeNoiseService(alerts: [], histories: {});

        await tester.pumpWidget(
          createSubject(
            user: testParentUser,
            deviceService: fakeDevService,
            noiseService: fakeNoiseService,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Chưa ghi nhận cảnh báo trong khoảng thời gian đã chọn.'),
          findsOneWidget,
        );
        expect(
          find.text(
            'Không có sự kiện vượt ngưỡng âm thanh nào từ thiết bị của con.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('TC09: Error state renders with retry button when API fails', (
      tester,
    ) async {
      final fakeDevService = FakeDeviceService(apiError('Mất kết nối máy chủ'));
      final fakeNoiseService = FakeNoiseService();

      await tester.pumpWidget(
        createSubject(
          user: testParentUser,
          deviceService: fakeDevService,
          noiseService: fakeNoiseService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Lỗi Tải Dữ Liệu An Toàn'), findsOneWidget);
      expect(find.text('Mất kết nối máy chủ'), findsOneWidget);
      expect(find.text('Thử Lại'), findsOneWidget);
    });
  });

  group('TASK 05.2: Multi-Viewport Responsive Tests (Zero Overflow Guarantee)', () {
    final viewports = [
      {'name': 'Compact (320x640)', 'size': const Size(320, 640)},
      {'name': 'Standard (360x800)', 'size': const Size(360, 800)},
      {'name': 'Modern (393x852)', 'size': const Size(393, 852)},
      {'name': 'Large (430x932)', 'size': const Size(430, 932)},
    ];

    for (final vp in viewports) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          'TC12: ${vp['name']} at font scale $scale renders cleanly with zero overflow',
          (tester) async {
            final size = vp['size'] as Size;
            tester.view.physicalSize = Size(
              size.width * 2.0,
              size.height * 2.0,
            );
            tester.view.devicePixelRatio = 2.0;

            FlutterErrorDetails? caughtError;
            final originalOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              caughtError = details;
              originalOnError?.call(details);
            };

            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
              FlutterError.onError = originalOnError;
            });

            final fakeDevService = FakeDeviceService(
              apiSuccess([testDevice1, testDevice2]),
            );
            final fakeNoiseService = FakeNoiseService(
              alerts: [testAlert1, testAlert2],
              histories: {10: testHistory1, 11: testHistory2},
            );

            await tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(scale),
                ),
                child: MaterialApp(
                  home: FamilySafetyInsightsScreen(
                    currentUser: testParentUser,
                    deviceService: fakeDevService,
                    noiseService: fakeNoiseService,
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(
              caughtError,
              isNull,
              reason:
                  'FamilySafetyInsightsScreen overflowed on $size at scale $scale',
            );
            expect(find.text('Góc An Toàn Gia Đình'), findsOneWidget);
          },
        );
      }
    }
  });
}
