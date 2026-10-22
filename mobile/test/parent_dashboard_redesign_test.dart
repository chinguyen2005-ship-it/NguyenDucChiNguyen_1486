import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nguyenducchinguyen_1486/models/auth_models.dart';
import 'package:nguyenducchinguyen_1486/screens/dashboard/parent_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testParent = UserProfile(
    id: 'parent-001',
    username: 'parent_tester',
    email: 'parent@kidguard.local',
    fullName: 'Nguyễn Văn Phụ Huynh',
    roles: ['Parent'],
    emailConfirmed: true,
  );

  group('Task 04.5: Parent Dashboard Redesign & Role Separation Tests', () {
    testWidgets('Removes Task 04 grading jargon and 3-button horizontal hub', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: ParentDashboardScreen(user: testParent)),
      );
      await tester.pump();

      // Ensure grading jargon / task 04 horizontal bar is completely gone
      expect(find.textContaining('Task 04'), findsNothing);
      expect(find.text('Tính Năng Nâng Cao (Task 04)'), findsNothing);
    });

    testWidgets(
      'Renders 4 functional groups: Tổng Quan, Quản Lý Trẻ Em, Theo Dõi & Quản Lý, Bảo Mật Tài Khoản',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: ParentDashboardScreen(user: testParent)),
        );
        await tester.pump();

        // Section A: Tổng quan
        expect(find.text('Tổng Quan Giám Sát'), findsOneWidget);
        expect(find.text('Thiết bị con'), findsOneWidget);
        expect(find.text('Đang khóa'), findsOneWidget);
        expect(find.text('Hồ sơ trẻ em'), findsOneWidget);
        expect(find.text('Cảnh báo ồn'), findsOneWidget);

        // Section B: Quản lý trẻ em
        expect(find.text('Quản Lý Trẻ Em'), findsOneWidget);
        expect(find.text('Thêm / Liên kết'), findsOneWidget);

        // Section C: Theo dõi & Quản lý
        expect(find.text('Theo Dõi & Quản Lý'), findsOneWidget);
        expect(find.text('Thiết Bị Của Trẻ Em'), findsOneWidget);
        expect(find.text('Giám Sát Mức Ồn Môi Trường'), findsOneWidget);
        expect(find.text('Tra Cứu Thiết Bị Bằng Mã QR'), findsOneWidget);

        // Section D: Bảo mật tài khoản
        expect(find.text('Bảo Mật Tài Khoản'), findsOneWidget);
        expect(find.text('Bảo Mật Khuôn Mặt (Face AI)'), findsOneWidget);
        expect(
          find.textContaining('Đăng ký mẫu khuôn mặt cho tài khoản phụ huynh'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Parent does NOT have a local microphone measurement trigger on Parent Dashboard',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: ParentDashboardScreen(user: testParent)),
        );
        await tester.pump();

        // Ensure NO "Bắt đầu đo" button on Parent's dashboard using Parent's microphone
        expect(find.text('Bắt đầu đo'), findsNothing);
        expect(find.text('Bắt Đầu Đo'), findsNothing);
        expect(find.text('Mở Máy Đo Độc Lập (Thử nghiệm)'), findsNothing);

        // Confirms Parent role principle is displayed
        expect(
          find.textContaining('Phụ huynh không trực tiếp dùng micro để đo'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Section D: Personal Face AI is isolated to Parent account and disclaims Child isolation',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: ParentDashboardScreen(user: testParent)),
        );
        await tester.pump();

        // Scroll to Section D
        await tester.ensureVisible(find.text('Bảo Mật Khuôn Mặt (Face AI)'));
        await tester.pump();

        expect(find.text('Đăng Ký Khuôn Mặt'), findsOneWidget);
        expect(
          find.textContaining(
            'Ứng dụng không truy cập hoặc can thiệp mẫu khuôn mặt của trẻ em',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Technical JWT Verification section is cleanly located in developer area',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: ParentDashboardScreen(user: testParent)),
        );
        await tester.pump();

        await tester.ensureVisible(
          find.text('Kiểm Thử Phân Quyền Backend Thực Tế (JWT)'),
        );
        await tester.pump();

        expect(
          find.text('Kiểm Thử Phân Quyền Backend Thực Tế (JWT)'),
          findsOneWidget,
        );
        expect(find.text('Test Devices (Kỳ vọng: 200)'), findsOneWidget);
        expect(find.text('Test Admin-Only (Kỳ vọng: 403)'), findsOneWidget);
      },
    );
  });

  group('Task 04.5: Multi-Viewport Responsive Tests on Redesigned Parent Dashboard', () {
    final viewports = [
      const Size(320, 640), // Compact Phone
      const Size(360, 800), // Standard Android
      const Size(393, 852), // iPhone 15 Class
      const Size(430, 932), // Large Phone
    ];

    for (final size in viewports) {
      for (final textScale in [1.0, 1.3]) {
        testWidgets(
          'ParentDashboardScreen renders cleanly on ${size.width}x${size.height} at scale $textScale',
          (tester) async {
            tester.view.physicalSize = Size(size.width * 2, size.height * 2);
            tester.view.devicePixelRatio = 2.0;

            FlutterErrorDetails? caughtError;
            final originalOnError = FlutterError.onError;
            FlutterError.onError = (FlutterErrorDetails details) {
              if (details.toString().contains('overflowed') ||
                  details.toString().contains('RenderFlex')) {
                caughtError = details;
              }
              originalOnError?.call(details);
            };

            await tester.pumpWidget(
              MediaQuery(
                data: MediaQueryData(
                  size: size,
                  textScaler: TextScaler.linear(textScale),
                ),
                child: MaterialApp(
                  home: ParentDashboardScreen(user: testParent),
                ),
              ),
            );
            await tester.pump();

            FlutterError.onError = originalOnError;
            expect(
              caughtError,
              isNull,
              reason:
                  'ParentDashboardScreen overflowed on ${size.width}x${size.height} at scale $textScale',
            );

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
