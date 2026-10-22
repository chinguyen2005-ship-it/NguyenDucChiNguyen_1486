import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenducchinguyen_1486/models/admin_user_model.dart';
import 'package:nguyenducchinguyen_1486/models/auth_models.dart';
import 'package:nguyenducchinguyen_1486/screens/auth/register_screen.dart';
import 'package:nguyenducchinguyen_1486/screens/dashboard/parent_dashboard_screen.dart';

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

  group('AdminUserModel Serialization & Role Helpers Tests', () {
    test('Correctly deserializes user with Child role and lockout state', () {
      final json = {
        'id': 'child-uuid-123',
        'userName': 'be_bap',
        'email': 'bebap@kidguard.vn',
        'emailConfirmed': true,
        'roles': ['Child'],
        'hasFace': false,
        'isLockedOut': false,
      };

      final user = AdminUserModel.fromJson(json);

      expect(user.id, 'child-uuid-123');
      expect(user.username, 'be_bap');
      expect(user.email, 'bebap@kidguard.vn');
      expect(user.emailConfirmed, isTrue);
      expect(user.isChild, isTrue);
      expect(user.isParent, isFalse);
      expect(user.isAdmin, isFalse);
      expect(user.primaryRole, 'Child');
      expect(user.isLockedOut, isFalse);
    });

    test(
      'Correctly identifies Parent and Admin roles and defaults missing roles',
      () {
        final jsonParent = {
          'id': 'parent-uuid-456',
          'userName': 'parent_test',
          'email': 'parent@kidguard.vn',
          'emailConfirmed': true,
          'roles': ['Parent'],
        };
        final userParent = AdminUserModel.fromJson(jsonParent);
        expect(userParent.isParent, isTrue);
        expect(userParent.isChild, isFalse);

        final jsonAdmin = {
          'id': 'admin-uuid-789',
          'userName': 'admin_root',
          'email': 'admin@kidguard.vn',
          'emailConfirmed': true,
          'roles': ['Admin'],
        };
        final userAdmin = AdminUserModel.fromJson(jsonAdmin);
        expect(userAdmin.isAdmin, isTrue);
        expect(userAdmin.isChild, isFalse);

        final jsonEmpty = {'id': 'empty-uuid', 'userName': 'guest'};
        final userEmpty = AdminUserModel.fromJson(jsonEmpty);
        expect(userEmpty.roles, isEmpty);
        expect(userEmpty.primaryRole, 'User');
      },
    );
  });

  group('RegisterScreen Role Selection Tests', () {
    testWidgets('RegisterScreen opens with initialRole Child and updates UI', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: RegisterScreen(initialRole: 'Child')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đăng Ký Tài Khoản Trẻ Em'), findsOneWidget);
      expect(find.text('Trẻ Em'), findsOneWidget);
      expect(find.text('Họ và tên trẻ em'), findsOneWidget);
      expect(find.text('Email trẻ em'), findsOneWidget);

      // Tap on Phụ Huynh button segment
      await tester.tap(find.text('Phụ Huynh'));
      await tester.pumpAndSettle();

      expect(find.text('Đăng Ký Tài Khoản Phụ Huynh'), findsOneWidget);
      expect(find.text('Họ và tên phụ huynh'), findsOneWidget);
      expect(find.text('Email phụ huynh'), findsOneWidget);
    });
  });

  group('ParentDashboardScreen Child Account Management Section Tests', () {
    testWidgets(
      'Renders Quản Lý Trẻ Em section with empty state when no devices exist',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: ParentDashboardScreen(user: testParentUser)),
        );
        await tester.pump();

        expect(find.text('Quản Lý Trẻ Em'), findsOneWidget);
        expect(find.text('Thêm / Liên kết'), findsOneWidget);
        expect(find.text('Chưa có hồ sơ trẻ em'), findsOneWidget);
        expect(find.text('Thêm / Liên Kết Trẻ Em'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping Thêm / Liên kết opens bottom sheet with 3 management options',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: ParentDashboardScreen(user: testParentUser)),
        );
        await tester.pump();

        // Tap the Thêm / Liên kết button
        final btnFinder = find.text('Thêm / Liên kết');
        await tester.ensureVisible(btnFinder);
        await tester.tap(btnFinder);
        await tester.pumpAndSettle();

        // Check modal bottom sheet title & 3 actions
        expect(find.text('Quản Lý & Liên Kết Trẻ Em'), findsOneWidget);
        expect(find.text('Gán Tài Khoản Trẻ Vào Thiết Bị'), findsOneWidget);
        expect(find.text('Đăng Ký Tài Khoản Cho Trẻ'), findsOneWidget);
        expect(find.text('Quy Trình & Hướng Dẫn Role Child'), findsOneWidget);

        // Tap Quy Trình & Hướng Dẫn Role Child to see explanation dialog
        await tester.tap(find.text('Quy Trình & Hướng Dẫn Role Child'));
        await tester.pumpAndSettle();

        expect(find.text('Quy Trình Role Child'), findsOneWidget);
        expect(find.text('1. Tạo tài khoản Child:'), findsOneWidget);
        expect(find.text('2. Liên kết vào thiết bị:'), findsOneWidget);
        expect(find.text('Đã hiểu'), findsOneWidget);

        await tester.tap(find.text('Đã hiểu'));
        await tester.pumpAndSettle();
      },
    );
  });

  group('Responsive Viewport Tests for Child Account Section', () {
    final viewports = [
      const Size(320, 640), // Small phone
      const Size(360, 800), // Standard Android
      const Size(393, 852), // iPhone 14/15/16 Pro
      const Size(430, 932), // Large phone / Pro Max
    ];

    for (final size in viewports) {
      testWidgets(
        'Renders cleanly on ${size.width}x${size.height} at scale 1.0 & 1.3',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          for (final scale in [1.0, 1.3]) {
            FlutterErrorDetails? caughtDetails;
            final originalOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              caughtDetails = details;
            };

            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: ParentDashboardScreen(user: testParentUser),
                ),
              ),
            );
            await tester.pump();

            FlutterError.onError = originalOnError;

            expect(find.text('Quản Lý Trẻ Em'), findsOneWidget);
            if (caughtDetails != null) {
              // ignore: avoid_print
              print(
                'DETAILED OVERFLOW on ${size.width}x${size.height} scale $scale:\n${caughtDetails!.exceptionAsString()}',
              );
            }
            expect(caughtDetails, isNull);
          }
        },
      );
    }
  });
}
