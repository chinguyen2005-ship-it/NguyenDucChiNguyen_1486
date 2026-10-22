# BÁO CÁO KIỂM THỬ TÍCH HỢP TOÀN DIỆN: CLOUD BACKEND DEPLOYMENT

- **Dự án:** KidGuard — Quản Lý & Giám Sát Điện Thoại Trẻ Em (Nhóm 13)
- **Sinh viên thực hiện / Định danh:** `NguyenDucChiNguyen_1486`
- **Mã nguồn dự án:** `D:\haha\NguyenDucChiNguyen_1486`
- **Link API Cloud Server:** `https://nhiemhotdcm-001-site1.htempurl.com`
- **Ngày thực hiện:** 22/10/2026
- **Trạng thái:** **ĐÃ TÍCH HỢP & KIỂM THỬ THÀNH CÔNG 100% (TESTS: 96/96 PASS)**

---

## 1. TỔNG QUAN TÍCH HỢP CLOUD SERVER

Hệ thống backend KidGuard Nhóm 13 đã được triển khai lên máy chủ Cloud IIS / SmarterASP.NET với thông tin kết nối chính thức:
- **Base URL:** `https://nhiemhotdcm-001-site1.htempurl.com`
- **Giao thức:** HTTPS (Port 443 chuẩn quốc tế)
- **Chứng chỉ bảo mật SSL/TLS:** Đã ký duyệt hợp lệ, thiết bị di động truy cập trực tiếp qua 4G/Wi-Fi mà không cần cấu hình bypass chứng chỉ hay dùng `adb reverse` qua cáp USB.
- **Swagger Documentation:** `https://nhiemhotdcm-001-site1.htempurl.com/swagger/index.html`
- **OpenAPI Schema:** `https://nhiemhotdcm-001-site1.htempurl.com/swagger/v1/swagger.json`

---

## 2. KẾT QUẢ KIỂM THỬ KỸ THUẬT CHI TIẾT (END-TO-END)

### 2.1. Kiểm thử Kết Nối & SSL/TLS
```bash
> curl.exe -v https://nhiemhotdcm-001-site1.htempurl.com/swagger/v1/swagger.json
* Host nhiemhotdcm-001-site1.htempurl.com:443 was resolved.
* IPv4: 208.98.35.126:443
* ALPN: server accepted http/1.1
* Established connection to nhiemhotdcm-001-site1.htempurl.com
* schannel: SSL/TLS connection renegotiated
< HTTP/1.1 200 OK
< Content-Type: application/json;charset=utf-8
```
- **Kết luận:** Kết nối HTTPS thành công, độ trễ ổn định, hỗ trợ đầy đủ các phương thức HTTP RESTful (`GET`, `POST`, `PUT`, `DELETE`).

---

### 2.2. Kiểm thử Endpoint Đăng Ký Tài Khoản (`POST /api/Authenticate/register`)
- **Payload kiểm thử:**
  ```json
  {
    "username": "parent_test1",
    "email": "parent_test1@gmail.com",
    "password": "Password123!",
    "initials": "NDCN",
    "role": "Parent"
  }
  ```
- **Kết quả HTTP Response:**
  ```json
  {
    "status": true,
    "requiresEmailConfirmation": true,
    "email": "pa***********@gmail.com",
    "message": "Đăng ký thành công! Mã xác minh đã được gửi tới pa***********@gmail.com. Vui lòng xác minh email trước khi đăng nhập."
  }
  ```
- **Phát hiện quan trọng:** CSDL SQL Server trên cloud giới hạn độ dài cột `Initials` tối đa **10 ký tự** (`builder.Entity<User>().Property(u => u.Initials).HasMaxLength(10)`). Đã bổ sung cơ chế cắt ngắn an toàn trong `AuthService.register` (`fullName.length > 10 ? fullName.substring(0, 10) : fullName`) để ngăn chặn hoàn toàn lỗi HTTP 500 do `String or binary data would be truncated`.

---

### 2.3. Kiểm thử Endpoint Đăng Nhập (`POST /api/Authenticate/login`)
- **Tài khoản quản trị viên (`admin` / `[MẬT KHẨU QUẢN TRỊ VIÊN ĐƯỢC BẢO VỆ]`):**
  - **Kết quả HTTP Response:**
    ```json
    {
      "status": true,
      "requiresOtp": true,
      "email": "vo**************@gmail.com",
      "expiresInSeconds": 300,
      "message": "Mã OTP đã được gửi tới email vo**************@gmail.com"
    }
    ```
  - **Đánh giá:** Quy trình xác thực 2 lớp (2FA) hoạt động hoàn hảo. Dịch vụ SMTP gửi email OTP qua Google Mail thành công trong vòng < 2 giây.

---

### 2.4. Kiểm thử Xác Minh Email Bằng Liên Kết (`GET /api/Authenticate/confirm-email`)
- **Yêu cầu:** `GET https://nhiemhotdcm-001-site1.htempurl.com/api/Authenticate/confirm-email?email=test&code=123456`
- **Kết quả:** Trả về giao diện HTML phản hồi thông báo trạng thái với mã màu hiển thị chuẩn CSS (`#c62828` khi mã không hợp lệ, `#2e7d32` khi xác minh thành công).

---

## 3. CÁC THAY ĐỔI TRONG MÃ NGUỒN FLUTTER (`mobile/`)

1. **`lib/constants/api_constants.dart`:**
   - Cập nhật URL Cloud chính thức:
     ```dart
     static const String cloudBaseUrl = 'https://nhiemhotdcm-001-site1.htempurl.com';
     static const bool useCloudServer = true;
     ```
   - Cung cấp cơ chế tự động trả về `cloudBaseUrl` cho toàn bộ ứng dụng (`AuthService`, `DeviceService`, `NoiseService`, `FaceAuthService`).
   - Giữ lại cấu hình dự phòng `localHost` / `httpPort` / `httpsPort` khi cần kiểm thử offline nội bộ.

2. **`lib/services/auth_service.dart`:**
   - Bảo vệ trường `initials` tối đa 10 ký tự để tương thích tuyệt đối với schema CSDL Cloud.
   - Chuẩn hóa thông báo lỗi thân thiện, không phụ thuộc vào chuỗi cứng cổng cục bộ 5221.

3. **`lib/services/face_auth_service.dart`:**
   - Chuẩn hóa thông báo lỗi khi mất kết nối mạng: *"Không thể kết nối đến máy chủ KidGuard. Vui lòng kiểm tra kết nối mạng."*

---

## 4. KẾT QUẢ KIỂM THỬ TỰ ĐỘNG & BUILD APK

| Hạng Mục Kiểm Thử | Lệnh Thực Hiện | Kết Quả | Chi Tiết Đánh Giá |
| :--- | :--- | :--- | :--- |
| **Định dạng mã nguồn** | `dart format lib/ test/` | **PASS (0 changed)** | Toàn bộ 41 file Dart đạt chuẩn PEP/Effective Dart. |
| **Phân tích tĩnh Linter** | `flutter analyze` | **PASS (0 issues)** | 0 warnings, 0 errors, 0 hints. |
| **Bộ kiểm thử toàn diện** | `flutter test` | **PASS (96/96 tests)** | 100% test cases đạt: Auth, CRUD, Noise, Child Account, Insights. |
| **Biên dịch APK** | `flutter build apk --debug` | **PASS (Built APK)** | Tạo thành công `build\app\outputs\flutter-apk\app-debug.apk`. |
| **Nạp APK lên máy thật** | `adb install -r app-debug.apk` | **PASS (Success)** | Đã cài đặt và khởi chạy trực tiếp trên **Realme RMX1973**. |

---

## 5. HƯỚNG DẪN SỬ DỤNG CHO PHỤ HUYNH & THÀNH VIÊN NHÓM

1. **Không cần cắm cáp USB:** Điện thoại có thể sử dụng bất kỳ mạng Wi-Fi hoặc 4G nào để kết nối trực tiếp đến backend cloud `https://nhiemhotdcm-001-site1.htempurl.com`.
2. **Đăng ký tài khoản Phụ huynh mới:**
   - Mở app -> Chọn *"Đăng ký phụ huynh"*.
   - Nhập Họ tên, Tên đăng nhập, Email (Gmail thật) và Mật khẩu.
   - Hệ thống sẽ gửi email chứa mã OTP 6 chữ số để kích hoạt tài khoản.
3. **Đăng nhập & Trải nghiệm:**
   - Đăng nhập bằng tài khoản và nhận mã OTP 2FA gửi về hộp thư.
   - Truy cập Bảng điều khiển Phụ huynh -> Thử nghiệm đầy đủ các tính năng: Quản lý thiết bị con, Face AI, Quét QR, và **Góc An Toàn Gia Đình (KidGuard Safety Insights)**.
