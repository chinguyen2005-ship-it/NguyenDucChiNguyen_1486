import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nguyenducchinguyen_1486/models/auth_models.dart';
import 'package:nguyenducchinguyen_1486/models/device_model.dart';
import 'package:nguyenducchinguyen_1486/screens/device/device_form_screen.dart';
import 'package:nguyenducchinguyen_1486/screens/device/device_list_screen.dart';
import 'package:nguyenducchinguyen_1486/screens/device/device_detail_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'jwt_token': 'mock_jwt_token_for_testing',
      'user_profile': '{"id":"p1","username":"parent_test","email":"parent@test.com","fullName":"Parent Test","roles":["Parent"],"emailConfirmed":true}',
    });
  });

  group('ChildDeviceModel Unit Tests', () {
    test('Correctly deserializes camelCase JSON from Backend API', () {
      final json = {
        'id': 10,
        'childName': 'Bé Nam',
        'deviceName': 'Samsung Galaxy Tab A9',
        'screenTimeLimitMinutes': 120,
        'blockedApps': 'TikTok, YouTube, Facebook',
        'isLocked': false,
        'noiseThresholdDb': 75.0,
        'parentUsername': 'parent_test',
        'childUsername': 'be_nam',
        'latitude': 10.7769,
        'longitude': 106.7009,
        'lastLocationUpdate': '2026-10-22T00:00:00Z',
      };

      final device = ChildDeviceModel.fromJson(json);

      expect(device.id, 10);
      expect(device.childName, 'Bé Nam');
      expect(device.deviceName, 'Samsung Galaxy Tab A9');
      expect(device.screenTimeLimitMinutes, 120);
      expect(device.isLocked, false);
      expect(device.noiseThresholdDb, 75.0);
      expect(device.parentUsername, 'parent_test');
      expect(device.childUsername, 'be_nam');
      expect(device.latitude, 10.7769);
      expect(device.longitude, 106.7009);
      expect(device.formattedScreenTime, '2h');
      expect(device.blockedAppList, ['TikTok', 'YouTube', 'Facebook']);
    });

    test('Correctly deserializes PascalCase JSON fallback', () {
      final json = {
        'Id': 20,
        'ChildName': 'Bé Linh',
        'DeviceName': 'iPad Mini 6',
        'ScreenTimeLimitMinutes': 45,
        'BlockedApps': 'Roblox,Discord',
        'IsLocked': true,
        'NoiseThresholdDb': 80.0,
      };

      final device = ChildDeviceModel.fromJson(json);

      expect(device.id, 20);
      expect(device.childName, 'Bé Linh');
      expect(device.deviceName, 'iPad Mini 6');
      expect(device.screenTimeLimitMinutes, 45);
      expect(device.isLocked, true);
      expect(device.formattedScreenTime, '45m');
      expect(device.blockedAppList, ['Roblox', 'Discord']);
    });

    test('ChildDeviceUpsertDto produces valid backend payload', () {
      const dto = ChildDeviceUpsertDto(
        childName: 'Bé An',
        deviceName: 'Xiaomi Pad 6',
        screenTimeLimitMinutes: 90,
        blockedApps: 'Facebook, Instagram',
        isLocked: false,
        noiseThresholdDb: 70.0,
        childUsername: 'be_an',
      );

      final payload = dto.toJson();

      expect(payload['childName'], 'Bé An');
      expect(payload['deviceName'], 'Xiaomi Pad 6');
      expect(payload['screenTimeLimitMinutes'], 90);
      expect(payload['blockedApps'], 'Facebook, Instagram');
      expect(payload['isLocked'], false);
      expect(payload['noiseThresholdDb'], 70.0);
      expect(payload['childUsername'], 'be_an');
    });

    test('copyWith properly modifies target fields', () {
      final original = ChildDeviceModel(
        id: 1,
        childName: 'Bé Test',
        deviceName: 'Phone',
        screenTimeLimitMinutes: 60,
        blockedApps: '',
        isLocked: false,
        noiseThresholdDb: 80.0,
      );

      final updated = original.copyWith(
        isLocked: true,
        screenTimeLimitMinutes: 180,
      );

      expect(updated.id, original.id);
      expect(updated.childName, original.childName);
      expect(updated.isLocked, true);
      expect(updated.screenTimeLimitMinutes, 180);
    });
  });

  group('DeviceFormScreen Widget Tests', () {
    testWidgets('Renders Create Device form with all required DTO fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DeviceFormScreen(defaultParentUsername: 'parent_test'),
        ),
      );

      expect(find.text('Thêm Thiết Bị Của Trẻ'), findsOneWidget);
      expect(find.text('Tên của trẻ *'), findsOneWidget);
      expect(find.text('Tên thiết bị *'), findsOneWidget);
      expect(find.text('Thời Gian Sử Dụng'), findsOneWidget);
      expect(find.text('Chặn Ứng Dụng'), findsOneWidget);
      expect(find.text('Khóa Thiết Bị Từ Xa'), findsOneWidget);
      expect(find.text('Ngưỡng cảnh báo tiếng ồn:'), findsOneWidget);
      expect(find.text('Tài khoản của trẻ (Tùy chọn)'), findsOneWidget);
      expect(find.text('Thêm Thiết Bị Mới'), findsOneWidget);
    });

    testWidgets('Validates required fields when saving empty form', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DeviceFormScreen(defaultParentUsername: 'parent_test'),
        ),
      );

      final saveButton = find.text('Thêm Thiết Bị Mới');
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập tên của trẻ'), findsOneWidget);
      expect(find.text('Vui lòng nhập tên thiết bị'), findsOneWidget);
    });

    testWidgets('Populates existing device data in Edit mode', (tester) async {
      final existingDevice = ChildDeviceModel(
        id: 99,
        childName: 'Nguyễn Văn Bé',
        deviceName: 'Oppo Reno 10',
        screenTimeLimitMinutes: 150,
        blockedApps: 'Facebook, TikTok',
        isLocked: true,
        noiseThresholdDb: 65.0,
        childUsername: 'vanbe',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceFormScreen(
            device: existingDevice,
            defaultParentUsername: 'parent_test',
          ),
        ),
      );

      expect(find.text('Chỉnh Sửa Thiết Bị'), findsOneWidget);
      expect(find.text('Nguyễn Văn Bé'), findsOneWidget);
      expect(find.text('Oppo Reno 10'), findsOneWidget);
      expect(find.text('Lưu Thay Đổi'), findsOneWidget);
    });
  });

  group('Role-Based UI Tests for Devices', () {
    final parentUser = UserProfile(
      id: 'p1',
      username: 'parent_user',
      email: 'parent@domain.com',
      fullName: 'Phụ Huynh Mẫu',
      roles: ['Parent'],
      emailConfirmed: true,
    );

    final childUser = UserProfile(
      id: 'c1',
      username: 'child_user',
      email: 'child@domain.com',
      fullName: 'Trẻ Em Mẫu',
      roles: ['Child'],
      emailConfirmed: true,
    );

    testWidgets('Parent role has Add Device FloatingActionButton', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: DeviceListScreen(currentUser: parentUser)),
      );

      await tester.pump();

      // Parent can see Add FAB
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('Thêm Thiết Bị'), findsOneWidget);
    });

    testWidgets('Child role DOES NOT have Add Device FloatingActionButton', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: DeviceListScreen(currentUser: childUser)),
      );

      await tester.pump();

      // Child MUST NOT see Add FAB
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Thêm Thiết Bị'), findsNothing);
    });

    testWidgets(
      'DeviceDetailScreen displays metrics and restricts actions for Child',
      (tester) async {
        final testDevice = ChildDeviceModel(
          id: 101,
          childName: 'Bé Linh Nhi',
          deviceName: 'Redmi Note 13',
          screenTimeLimitMinutes: 90,
          blockedApps: 'TikTok',
          isLocked: false,
          noiseThresholdDb: 75.0,
          parentUsername: 'parent_user',
          latitude: 10.762622,
          longitude: 106.660172,
        );

        // 1. Parent view: has Edit and Delete actions
        await tester.pumpWidget(
          MaterialApp(
            home: DeviceDetailScreen(
              device: testDevice,
              currentUser: parentUser,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Bé Linh Nhi'), findsWidgets);
        expect(find.text('Redmi Note 13'), findsOneWidget);
        expect(find.byIcon(Icons.edit_rounded), findsWidgets);
        expect(find.byIcon(Icons.delete_outline_rounded), findsWidgets);
        expect(find.text('Khóa máy'), findsOneWidget);

        // 2. Child view: NO Edit, Delete, or Lock Switch
        await tester.pumpWidget(
          MaterialApp(
            home: DeviceDetailScreen(
              device: testDevice,
              currentUser: childUser,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Bé Linh Nhi'), findsWidgets);
        expect(find.byIcon(Icons.edit_rounded), findsNothing);
        expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
        expect(find.text('Khóa máy'), findsNothing);
      },
    );
  });

  group('Delete Confirmation Dialog Tests', () {
    testWidgets('Cancelling delete dialog does not execute deletion', (
      tester,
    ) async {
      final parentUser = UserProfile(
        id: 'p1',
        username: 'parent_user',
        email: 'parent@domain.com',
        fullName: 'Phụ Huynh Mẫu',
        roles: ['Parent'],
        emailConfirmed: true,
      );

      final testDevice = ChildDeviceModel(
        id: 102,
        childName: 'Bé Hoàng',
        deviceName: 'Galaxy A54',
        screenTimeLimitMinutes: 60,
        blockedApps: '',
        isLocked: false,
        noiseThresholdDb: 80.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DeviceDetailScreen(device: testDevice, currentUser: parentUser),
        ),
      );
      await tester.pump();

      // Tap Delete in AppBar
      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.delete_outline_rounded),
      );
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.text('Xác Nhận Xóa Thiết Bị'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Xóa Vĩnh Viễn'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      // Dialog dismissed, still on Detail screen
      expect(find.text('Xác Nhận Xóa Thiết Bị'), findsNothing);
      expect(find.text('Galaxy A54'), findsOneWidget);
    });
  });

  group('Responsive Viewport & Text Scale Tests (360x800 & 393x852, scale 1.0 & 1.3)', () {
    final parentUser = UserProfile(
      id: 'p1',
      username: 'parent_user',
      email: 'parent@domain.com',
      fullName: 'Phụ Huynh Mẫu',
      roles: ['Parent'],
      emailConfirmed: true,
    );

    final viewports = [const Size(360, 800), const Size(393, 852)];

    final scales = [1.0, 1.3];

    for (final size in viewports) {
      for (final scale in scales) {
        testWidgets(
          'DeviceFormScreen renders cleanly on ${size.width}x${size.height} at scale $scale',
          (tester) async {
            tester.view.physicalSize = Size(
              size.width * 2.0,
              size.height * 2.0,
            );
            tester.view.devicePixelRatio = 2.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: const DeviceFormScreen(
                    defaultParentUsername: 'parent_user',
                  ),
                ),
              ),
            );

            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'No RenderFlex overflow on ${size.width}x${size.height} scale $scale',
            );
          },
        );

        testWidgets(
          'DeviceDetailScreen renders cleanly on ${size.width}x${size.height} at scale $scale',
          (tester) async {
            tester.view.physicalSize = Size(
              size.width * 2.0,
              size.height * 2.0,
            );
            tester.view.devicePixelRatio = 2.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            final sampleDevice = ChildDeviceModel(
              id: 1,
              childName:
                  'Nguyễn Đức Trí - Tên Rất Dài Để Kiểm Tra Tràn Viền Màn Hình',
              deviceName: 'Samsung Galaxy S24 Ultra Bản Giới Hạn',
              screenTimeLimitMinutes: 120,
              blockedApps: 'YouTube, TikTok, Facebook, Instagram, Roblox',
              isLocked: true,
              noiseThresholdDb: 78.5,
              latitude: 10.7769,
              longitude: 106.7009,
            );

            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: DeviceDetailScreen(
                    device: sampleDevice,
                    currentUser: parentUser,
                  ),
                ),
              ),
            );

            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'No RenderFlex overflow on ${size.width}x${size.height} scale $scale',
            );
          },
        );
      }
    }
  });
}
