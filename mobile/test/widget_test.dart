import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenducchinguyen_1486/main.dart';
import 'package:nguyenducchinguyen_1486/models/auth_models.dart';
import 'package:nguyenducchinguyen_1486/screens/auth/login_screen.dart';
import 'package:nguyenducchinguyen_1486/screens/auth/register_screen.dart';
import 'package:nguyenducchinguyen_1486/screens/dashboard/parent_dashboard_screen.dart';
import 'package:nguyenducchinguyen_1486/widgets/otp_input_fields.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('KidGuardApp smoke test and splash screen display', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KidGuardApp());

    expect(find.text('KidGuard'), findsOneWidget);
    expect(find.text('NguyenDucChiNguyen_1486'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Advance delayed timer
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('LoginScreen displays required fields and buttons', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Đăng Nhập KidGuard'), findsOneWidget);
    expect(find.text('Tên đăng nhập hoặc Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Đăng Nhập (Nhận mã OTP)'), findsOneWidget);
    expect(find.text('Đăng ký phụ huynh'), findsOneWidget);
  });

  testWidgets('RegisterScreen displays parent registration fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    expect(find.text('Đăng Ký Tài Khoản Phụ Huynh'), findsOneWidget);
    expect(find.text('Họ và tên phụ huynh'), findsOneWidget);
    expect(find.text('Tên đăng nhập'), findsOneWidget);
    expect(find.text('Email phụ huynh'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
    expect(find.text('Xác nhận mật khẩu'), findsOneWidget);
    expect(find.text('Đăng Ký & Nhận Mã OTP'), findsOneWidget);
  });

  testWidgets('OtpInputFields renders exactly 6 input fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OtpInputFields(length: 6, onCompleted: (_) {})),
      ),
    );

    expect(find.byType(TextField), findsNWidgets(6));
  });

  testWidgets(
    'ParentDashboardScreen displays role and live verification section',
    (WidgetTester tester) async {
      final testParent = UserProfile(
        id: 'parent-123',
        username: 'test_parent',
        email: 'parent@kidguard.local',
        fullName: 'Nguyễn Văn Phụ Huynh',
        roles: ['Parent'],
        emailConfirmed: true,
      );

      await tester.pumpWidget(
        MaterialApp(home: ParentDashboardScreen(user: testParent)),
      );

      expect(find.text('Bảng Điều Khiển Phụ Huynh'), findsOneWidget);
      expect(find.text('Nguyễn Văn Phụ Huynh'), findsOneWidget);
      expect(find.text('ROLE: PARENT (PHỤ HUYNH)'), findsOneWidget);
      expect(
        find.text('Kiểm Thử Phân Quyền Backend Thực Tế (JWT)'),
        findsOneWidget,
      );
    },
  );
}
