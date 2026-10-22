import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nguyenducchinguyen_1486/services/face_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'kidguard_jwt_token': 'mock_jwt_token_for_face_test',
    });
  });

  group('FaceAuthService Robust Error Handling & Safe JSON Tests', () {
    test('TC-FACE-01: registerFace handles HTTP 500 with EMPTY body gracefully without FormatException', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 500); // Empty body as returned by IIS cloud host
      });

      final service = FaceAuthService(client: mockClient);
      final result = await service.registerFace('mock_base64_data');

      expect(result.success, isFalse);
      expect(result.message, isNot(contains('FormatException')));
      expect(result.message, isNot(contains('Unexpected end of input')));
      expect(result.message, contains('500'));
      expect(result.message, contains('ArcFace ONNX'));
    });

    test('TC-FACE-02: registerFace handles HTTP 502 HTML error page gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('<html><body>502 Bad Gateway</body></html>', 502);
      });

      final service = FaceAuthService(client: mockClient);
      final result = await service.registerFace('mock_base64_data');

      expect(result.success, isFalse);
      expect(result.message, isNot(contains('FormatException')));
      expect(result.message, contains('502'));
    });

    test('TC-FACE-03: registerFace handles HTTP 400 Bad Request with server message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': false,
            'message': 'Không tìm thấy khuôn mặt trong ảnh. Hãy chụp chính diện, đủ sáng!',
          }),
          400,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = FaceAuthService(client: mockClient);
      final result = await service.registerFace('mock_base64_data');

      expect(result.success, isFalse);
      expect(result.message, equals('Không tìm thấy khuôn mặt trong ảnh. Hãy chụp chính diện, đủ sáng!'));
    });

    test('TC-FACE-04: registerFace handles HTTP 401 Unauthorized with clean guidance', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 401);
      });

      final service = FaceAuthService(client: mockClient);
      final result = await service.registerFace('mock_base64_data');

      expect(result.success, isFalse);
      expect(result.message, contains('Phiên đăng nhập đã hết hạn'));
    });

    test('TC-FACE-05: registerFace handles HTTP 413 Payload Too Large cleanly', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 413);
      });

      final service = FaceAuthService(client: mockClient);
      final result = await service.registerFace('mock_base64_data');

      expect(result.success, isFalse);
      expect(result.message, contains('quá lớn'));
    });

    test('TC-FACE-06: registerFace succeeds on HTTP 200 with status: true', () async {
      final mockClient = MockClient((request) async {
        final bodyBytes = utf8.encode(
          jsonEncode({
            'status': true,
            'message': 'Đăng ký khuôn mặt thành công!',
          }),
        );
        return http.Response.bytes(
          bodyBytes,
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = FaceAuthService(client: mockClient);
      final result = await service.registerFace('mock_base64_data');

      expect(result.success, isTrue);
      expect(result.message, equals('Đăng ký khuôn mặt thành công!'));
    });

    test('TC-FACE-07: deleteFace handles empty body gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 500);
      });

      final service = FaceAuthService(client: mockClient);
      final result = await service.deleteFace();

      expect(result.success, isFalse);
      expect(result.message, isNot(contains('FormatException')));
    });

    test('TC-FACE-08: loginWithFace handles HTTP 500 empty body gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('', 500);
      });

      final service = FaceAuthService(client: mockClient);
      final result = await service.loginWithFace(
        username: 'nhiem',
        base64Image: 'mock_base64_data',
      );

      expect(result.success, isFalse);
      expect(result.message, isNot(contains('FormatException')));
      expect(result.message, contains('500'));
    });

    test('TC-FACE-09: checkHasFace handles malformed body without crash', () async {
      final mockClient = MockClient((request) async {
        return http.Response('invalid-non-json', 200);
      });

      final service = FaceAuthService(client: mockClient);
      final hasFace = await service.checkHasFace();

      expect(hasFace, isFalse);
    });
  });
}
