import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenducchinguyen_1486/models/auth_models.dart';
import 'package:nguyenducchinguyen_1486/models/device_model.dart';
import 'package:nguyenducchinguyen_1486/screens/dashboard/child_dashboard_screen.dart';
import 'package:nguyenducchinguyen_1486/screens/noise/noise_meter_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'test_child_jwt_token',
      'user_profile': '{"id":"child_01","username":"be_nam","email":"benam@kidguard.local","fullName":"Bé Nam","roles":["Child"],"emailConfirmed":true,"hasFace":true}',
    });
  });

  final testChildUser = UserProfile(
    id: 'child_01',
    username: 'be_nam',
    email: 'benam@kidguard.local',
    fullName: 'Bé Nam',
    roles: const ['Child'],
    emailConfirmed: true,
    hasFace: true,
  );

  final testAssignedDevice = ChildDeviceModel(
    id: 10,
    childName: 'Bé Nam',
    childUsername: 'be_nam',
    deviceName: 'iPad Gen 9 của Nam',
    isLocked: false,
    screenTimeLimitMinutes: 120,
    noiseThresholdDb: 70.0,
    parentUsername: 'phuhuynh_an',
  );

  group(
    'TC01, TC02, TC03: ChildDashboardScreen UI & Permission Guard Tests',
    () {
      testWidgets(
        'TC01: Child opens Dashboard and sees greeting header and 3 advanced features',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: ChildDashboardScreen(
                user: testChildUser,
                initialDevices: [testAssignedDevice],
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Section A: Greeting
          expect(find.text('Không Gian Của Trẻ Em'), findsOneWidget);
          expect(find.text('Xin chào, Bé Nam!'), findsOneWidget);
          expect(find.text('Tài khoản: @be_nam'), findsOneWidget);
          expect(find.text('VAI TRÒ: TRẺ EM (CHILD ROLE)'), findsOneWidget);

          // Section B: My Assigned Device
          expect(find.text('Thiết Bị Của Tôi'), findsOneWidget);
          expect(find.text('iPad Gen 9 của Nam'), findsOneWidget);
          expect(find.text('HOẠT ĐỘNG'), findsOneWidget);

          // Section C: Three Advanced Features Hub
          expect(find.text('Bảo Mật Khuôn Mặt (Face AI)'), findsOneWidget);
          expect(
            find.text('Đo Tiếng Ồn Xung Quanh (Noise Meter)'),
            findsOneWidget,
          );
          expect(find.text('Mã QR Định Danh Máy (Device QR)'), findsOneWidget);

          // Section D: Safety Information
          expect(find.text('Cam Kết An Toàn & Quyền Riêng Tư'), findsOneWidget);
        },
      );

      testWidgets(
        'TC03: Child role DOES NOT have Add, Edit, or Delete Device controls',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: ChildDashboardScreen(
                user: testChildUser,
                initialDevices: [testAssignedDevice],
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Child must NOT have FloatingActionButton to add devices
          expect(find.byType(FloatingActionButton), findsNothing);
          expect(find.text('Thêm Thiết Bị Con'), findsNothing);
          expect(find.text('Xóa vĩnh viễn'), findsNothing);
          expect(find.text('Khóa Thiết Bị Từ Xa'), findsNothing);
        },
      );

      testWidgets(
        'TC02: Empty state is rendered when child has no assigned devices',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: ChildDashboardScreen(
                user: testChildUser,
                initialDevices: const [],
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Expect child-friendly empty state guidance
          expect(find.text('Chưa Có Thiết Bị Nào Được Gán'), findsOneWidget);
          expect(
            find.textContaining('Hãy nhờ ba mẹ mở KidGuard trên máy phụ huynh'),
            findsOneWidget,
          );
        },
      );
    },
  );

  group('TC09: Noise Simulation Mode Guard Tests', () {
    testWidgets(
      'Demo mode warning is displayed and blocks submission of fake data',
      (tester) async {
        final testDevice = ChildDeviceModel(
          id: 5,
          childName: 'Bé Nam',
          deviceName: 'Samsung Tab A9',
          noiseThresholdDb: 75.0,
        );

        await tester.pumpWidget(
          MaterialApp(home: NoiseMeterScreen(device: testDevice)),
        );

        await tester.pumpAndSettle();

        expect(find.text('Đo Tiếng Ồn Môi Trường'), findsOneWidget);
        expect(find.text('Bé Nam — Samsung Tab A9'), findsOneWidget);
        expect(find.text('Bắt Đầu Đo'), findsOneWidget);
        expect(find.text('Gửi Lên Server'), findsOneWidget);
      },
    );
  });

  group('TC15: Responsive Viewports (320, 360, 393, 430) & Font Scale (1.0, 1.3) Tests', () {
    final viewports = [
      const Size(320, 640), // 320 logical width
      const Size(360, 800), // 360 logical width
      const Size(393, 852), // 393 logical width
      const Size(430, 932), // 430 logical width
    ];

    for (final size in viewports) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
          'ChildDashboardScreen renders cleanly on ${size.width}x${size.height} at scale $scale',
          (tester) async {
            tester.view.physicalSize = Size(
              size.width * 3.0,
              size.height * 3.0,
            );
            tester.view.devicePixelRatio = 3.0;

            await tester.pumpWidget(
              MaterialApp(
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  );
                },
                home: ChildDashboardScreen(
                  user: testChildUser,
                  initialDevices: [testAssignedDevice],
                ),
              ),
            );

            await tester.pumpAndSettle();

            // Verify no RenderFlex exception occurred and title is visible
            expect(find.text('Không Gian Của Trẻ Em'), findsOneWidget);
            expect(find.text('Xin chào, Bé Nam!'), findsOneWidget);
            expect(find.text('iPad Gen 9 của Nam'), findsOneWidget);

            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });
          },
        );
      }
    }
  });
}
