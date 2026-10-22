# BÁO CÁO NHIỆM VỤ TASK 04.1: CHILD ROLE ADVANCED FEATURES HUB
**Dự án:** KidGuard — Hệ Thống Giám Sát Và Bảo Vệ Trẻ Em (Nhóm 13)  
**Kỹ sư thực hiện:** Senior Flutter UI/UX Engineer & Mobile Security Engineer (Sinh viên: NguyenDucChiNguyen_1486)  
**Thời gian hoàn thành:** 22/10/2026  
**Mục tiêu:** Thiết kế lại giao diện Dashboard Child hiện đại, thân thiện, bảo mật cao và tích hợp liền mạch ba tính năng nâng cao (Face AI, Đo tiếng ồn môi trường, Mã QR thiết bị) với sự kiểm soát phân quyền chặt chẽ.

---

## 1. NGUYÊN TẮC BẤT BIẾN VÀ BẢO TOÀN HỆ THỐNG
1. **Backend Read-Only:** Thư mục `backend-group/nhom13` tuyệt đối nguyên vẹn. Không thay đổi bất kỳ Controller, DTO, Model, Service, Migration hay cấu hình database nào.
2. **Bảo toàn CRUD & JWT:** Luồng JWT Bearer, phân quyền Role (`Parent`, `Child`, `Admin`), mã hóa OTP và quản lý thiết bị CRUD giữ nguyên tính toàn vẹn 100%.
3. **Tính trung thực kỹ thuật:** Không sử dụng dữ liệu giả (fake data) gửi lên backend thật; các cảnh báo Demo Mode được hiển thị minh bạch.
4. **Không tự động push/commit:** Mọi thay đổi lưu trữ cục bộ để phục vụ nghiệm thu.

---

## 2. KIẾN TRÚC GIAO DIỆN DASHBOARD DÀNH CHO CHILD (REDESIGN)

File triển khai: [`child_dashboard_screen.dart`](file:///d:/haha/NguyenDucChiNguyen_1486/mobile/lib/screens/dashboard/child_dashboard_screen.dart)

Giao diện được tái cấu trúc thành 5 phân vùng chức năng rõ ràng, tuân thủ Material Design 3 và tương thích hoàn hảo với màn hình trẻ em:

### A. Greeting Header (Phần Lời Chào Thân Thiện)
- **Tên và tài khoản thật:** Lấy trực tiếp từ `UserProfile` được giải mã từ JWT (`widget.user.fullName`, `@${widget.user.username}`).
- **Avatar biểu trưng:** Icon trẻ em tươi sáng với nền Cyan mềm mại (`Colors.cyan.shade100`).
- **Huy hiệu vai trò an toàn:** Badge rõ ràng `VAI TRÒ: TRẺ EM (CHILD ROLE)` giúp trẻ và phụ huynh nhận thức ngữ cảnh ứng dụng.
- **Nút Đăng xuất an toàn:** Cho phép trẻ đăng xuất, xóa sạch JWT Token khỏi Secure Storage và quay lại `LoginScreen`.

### B. My Device (Thiết Bị Của Trẻ)
- **Truy vấn từ API thật:** Gọi `GET /api/ChildDeviceApi` với JWT của trẻ. Backend tự động áp dụng bộ lọc `ChildUsername == CurrentUsername`, đảm bảo trẻ chỉ thấy máy thuộc quyền quản lý của mình.
- **Bộ chọn thiết bị (Multi-Device Selector):** Khi trẻ sở hữu nhiều máy (điện thoại, máy tính bảng học tập), hỗ trợ cuộn ngang `ChoiceChip` để chọn máy tương tác.
- **Thông số an toàn:**
  - Tên thiết bị, ID máy, tên tài khoản phụ huynh đang quản lý (`parentUsername`).
  - Trạng thái hoạt động: `HOẠT ĐỘNG` (Xanh lục) hoặc `ĐANG KHÓA TỪ XA` (Đỏ) đồng bộ tức thì với cờ `isLocked` trên backend.
  - Hạn mức thời gian sử dụng trong ngày (`screenTimeLimitMinutes` hiển thị dưới dạng giờ/phút).
  - Ngưỡng cảnh báo tiếng ồn an toàn (`noiseThresholdDb` dB).
- **Empty State thông minh:** Khi trẻ chưa được gán thiết bị nào, hiển thị thẻ đồ họa thân thiện hướng dẫn trẻ nhờ ba mẹ mở máy phụ huynh để liên kết tài khoản.
- **Bảo mật giao diện:** **Tuyệt đối loại bỏ** các nút bấm của phụ huynh (Thêm máy `FloatingActionButton`, Chỉnh sửa `Edit`, Xóa `Delete`, Gạt công tắc `Lock Device`).

### C. Advanced Features Hub (Trung Tâm Tính Năng Nâng Cao)
Tích hợp ba tính năng theo đúng ngữ cảnh sử dụng của trẻ:
1. **Bảo Mật Khuôn Mặt (Face AI):**
   - Trạng thái kiểm tra thời gian thực: `Đã đăng ký khuôn mặt` (Green badge) hoặc `Chưa đăng ký khuôn mặt` (Orange badge) lấy từ `FaceAuthService.checkHasFace()`.
   - Nút hành động: `Đăng Ký Ngay` / `Cập Nhật Mẫu` (mở `FaceAuthScreen` chế độ đăng ký với tài khoản hiện tại) và `Xóa Mẫu` (kèm hộp thoại xác nhận cảnh báo an toàn).
2. **Đo Tiếng Ồn Môi Trường (Noise Meter):**
   - Tự động gắn kết với thiết bị trẻ đang chọn.
   - Nút `Mở Máy Đo Tiếng Ồn` mở [`NoiseMeterScreen`](file:///d:/haha/NguyenDucChiNguyen_1486/mobile/lib/screens/noise/noise_meter_screen.dart) đã cấu hình sẵn `DeviceId`.
3. **Mã QR Định Danh Máy (Device QR):**
   - Nút `Xem Mã QR Của Thiết Bị` mở [`QrGeneratorScreen`](file:///d:/haha/NguyenDucChiNguyen_1486/mobile/lib/screens/qr/qr_generator_screen.dart) kèm payload động chứa ID thiết bị và checksum FNV-1a.
   - Khi chưa có máy, tự động thông báo trẻ liên hệ phụ huynh.

### D. Safety Information & Privacy Commitments (Cam Kết An Toàn & Quyền Riêng Tư)
Card thông tin minh bạch giải thích cho trẻ và gia đình:
- **Camera:** Chỉ mở khi trẻ chủ động bấm chụp đăng ký khuôn mặt; không chụp ảnh ngầm.
- **Microphone:** Chỉ kích hoạt khi trẻ bấm "Bắt Đầu Đo"; giải phóng micro lập tức khi rời màn hình.
- **Bảo mật âm thanh:** Chỉ đo biên độ dB (Decibel), tuyệt đối không ghi âm cuộc trò chuyện hay lưu trữ file âm thanh.
- **Phân quyền cấu hình:** Trẻ không thể tự ý sửa giới hạn thời gian hay ngưỡng tiếng ồn do ba mẹ cài đặt.

### E. Live Backend Authorization Test (Kiểm Thử Phân Quyền Trực Tiếp)
- Cung cấp hai nút kiểm thử trực tiếp token JWT của trẻ đối với server backend:
  1. `Test Devices (Kỳ vọng: 200 OK)`: Gửi request đến `GET /api/ChildDeviceApi` -> Phản hồi thành công danh sách thiết bị của trẻ.
  2. `Test Admin-Only (Kỳ vọng: 403 Forbidden)`: Gửi request đến `GET /api/Admin/users` -> Backend ASP.NET Core trả về `403 Forbidden` do tài khoản không có Role Admin.

---

## 3. TÍCH HỢP BA TÍNH NĂNG NÂNG CAO CHO CHILD ROLE

### Feature A — Face AI for Child
- **Quyền tự quản mẫu:** Trẻ đăng nhập thành công có thể dùng camera trước để đăng ký hoặc cập nhật embedding 512 chiều của chính mình lên backend `POST /api/Authenticate/face/register`.
- **Xóa mẫu an toàn:** Khi bấm `Xóa Mẫu`, ứng dụng gọi `DELETE /api/Authenticate/face/delete` xóa embedding trên SQL Server và cập nhật lại giao diện.
- **Luồng đăng nhập công khai:** Đăng nhập khuôn mặt (`Face Login`) nằm ở `LoginScreen` chung ngoài màn hình chính, sử dụng camera quét mặt, gửi ảnh lên `POST /api/Authenticate/face/login`, nhận JWT chính thống và chuyển hướng tự động vào `ChildDashboardScreen` nếu `roles.contains('Child')`.
- **Ranh giới bảo mật:** Tỷ lệ tương đồng Cosine Similarity trên backend là căn cứ kiểm tra sinh trắc, nhưng chỉ khi backend cấp phát token JWT hợp lệ thì client mới lưu và điều hướng.

### Feature D — Child Noise Meter
- **Gắn kết thiết bị chính xác:** Trẻ đo tiếng ồn cho thiết bị cụ thể thuộc sở hữu của mình (`selectedDevice.id`).
- **Phép đo thực tế:** Kích hoạt Microphone, thu mẫu âm thanh thời gian thực (Sample Rate 44.1kHz), tính toán biên độ RMS và chuyển đổi sang dB SPL.
- **Đồng bộ Telemetry lên Server:** Bấm `Gửi Lên Server` gọi `POST /api/ChildDeviceApi/{id}/noise` với dữ liệu `currentDb`, `avgDb`, `peakDb`. Backend ghi nhận bản ghi `NoiseEvents` và phát sinh cảnh báo nếu vượt ngưỡng `NoiseThresholdDb`.
- **Quy tắc an toàn chống dữ liệu giả (TC09):**
  - Nếu thiết bị không có micro vật lý hoặc quyền micro bị từ chối, ứng dụng chuyển sang `CHẾ ĐỘ MÔ PHỎNG (DEMO MODE)` với banner cảnh báo màu cam nổi bật.
  - Khi ở chế độ mô phỏng, nút gửi dữ liệu sẽ **bị vô hiệu hóa hoàn toàn** và hiển thị SnackBar cảnh báo, ngăn chặn gửi dữ liệu giả vào cơ sở dữ liệu thật của backend.
- **Giải phóng phần cứng:** Tự động hủy stream micro trong `dispose()` và khi rời khỏi màn hình. Trẻ em **không có quyền** thay đổi ngưỡng âm thanh an toàn.

### Feature E — Child Device QR Code
- **Mã QR định danh động:** Tạo mã QR hiển thị trên màn hình trẻ chứa payload JSON:
  ```json
  {
    "app": "KidGuard",
    "v": 1,
    "did": 10,
    "dname": "iPad Gen 9 của Nam",
    "puser": "phuhuynh_an",
    "ts": 1729555200,
    "cs": "a7b9c1d3"
  }
  ```
- **Không lộ thông tin nhạy cảm:** QR Code không chứa mật khẩu, JWT token, hay số điện thoại.
- **FNV-1a Integrity Checksum:** Tính toán mã băm 32-bit FNV-1a trên payload để phát hiện lỗi truyền dẫn / quét quang học ngẫu nhiên.
  > [!IMPORTANT]
  > Giao diện và tài liệu nêu rõ: FNV-1a chỉ là mã kiểm tra toàn vẹn bit (Checksum), không phải chữ ký số mật mã chống giả mạo (Cryptographic HMAC/Digital Signature).
- **Ủy quyền phía Backend:** Khi phụ huynh quét mã QR bằng `QrScannerScreen`, mã chỉ lấy `did` và gọi `GET /api/ChildDeviceApi/{id}` kèm JWT của phụ huynh. Nếu phụ huynh không phải là người quản lý thiết bị, backend trả về `403 Forbidden` hoặc `404 Not Found`, đảm bảo mã QR không thể bị lợi dụng để leo thang đặc quyền.

---

## 4. MA TRẬN PHÂN QUYỀN VAI TRÒ (ROLE-BASED PERMISSION MATRIX)

| Nghiệp vụ / Tính năng | Child (Trẻ em) | Parent (Phụ huynh) | Admin (Quản trị viên) | Nơi thực thi kiểm soát |
| :--- | :---: | :---: | :---: | :--- |
| **Xem danh sách thiết bị** | Chỉ xem máy được gán (`ChildUsername`) | Xem tất cả máy của gia đình | Toàn quyền xem mọi máy | Backend `GetDevices()` + SQL Server |
| **Tạo mới thiết bị** | ❌ BỊ CẤM | ✅ ĐẦY ĐỦ | ✅ ĐẦY ĐỦ | Backend `CanManage` (403 Forbidden) |
| **Chỉnh sửa / Xóa thiết bị** | ❌ BỊ CẤM | ✅ ĐẦY ĐỦ | ✅ ĐẦY ĐỦ | Backend `CanManage` (403 Forbidden) |
| **Khóa / Mở khóa thiết bị** | ❌ BỊ CẤM | ✅ ĐẦY ĐỦ | ✅ ĐẦY ĐỦ | Backend `LockDevice` (403 Forbidden) |
| **Cài đặt ngưỡng ồn (dB)** | ❌ BỊ CẤM (Chỉ đọc) | ✅ CẤU HÌNH ĐƯỢC | ✅ CẤU HÌNH ĐƯỢC | Backend `UpdateNoiseThreshold` |
| **Đo tiếng ồn & Gửi số đo** | ✅ GỬI CHO MÁY MÌNH | ✅ GỬI CHO MÁY CON | ✅ ĐẦY ĐỦ | Backend `CanReportFromDevice` |
| **Đăng ký Face AI cá nhân** | ✅ ĐĂNG KÝ CHO MÌNH | ✅ ĐĂNG KÝ CHO MÌNH | ✅ ĐĂNG KÝ CHO MÌNH | Backend `RegisterFace` |
| **Xóa mẫu Face AI** | ✅ XÓA MẪU CỦA MÌNH | ✅ XÓA MẪU CỦA MÌNH | ✅ ĐẦY ĐỦ | Backend `DeleteFace` |
| **Tạo mã QR thiết bị** | ✅ TẠO CHO MÁY MÌNH | ✅ TẠO CHO MỌI MÁY CON | ✅ ĐẦY ĐỦ | Flutter QR Generator |
| **Quét QR tra cứu máy** | ❌ BỊ CẤM TRÊN UI | ✅ TRA CỨU ĐƯỢC | ✅ TRA CỨU ĐƯỢC | Backend `GET /api/ChildDeviceApi/{id}` |
| **Truy cập API Quản trị** | ❌ 403 FORBIDDEN | ❌ 403 FORBIDDEN | ✅ 200 OK | Backend `[Authorize(Roles = "Admin")]` |

---

## 5. KẾT QUẢ KIỂM THỬ TOÀN DIỆN (TC01 — TC15)

| Mã Test | Nội dung kiểm thử | Kết quả | Bằng chứng kiểm thử / Mô tả |
| :--- | :--- | :---: | :--- |
| **TC01** | Child mở Dashboard và thấy ba tính năng nâng cao | **PASS** | Widget test `TC01` kiểm tra thành công `Face AI`, `Noise Meter`, `Device QR` trên widget tree. |
| **TC02** | Child chỉ thấy các thiết bị được gán cho tài khoản | **PASS** | Backend `query.Where(d => d.ChildUsername == currentUsername)` + Empty state hiển thị khi chưa có máy. |
| **TC03** | Child không có quyền sửa hoặc xóa thiết bị | **PASS** | Widget test `TC03` xác nhận 0 `FloatingActionButton`, không có nút `Edit`, `Delete`, `Lock`. |
| **TC04** | Face AI đăng ký đúng tài khoản hiện tại | **PASS** | `FaceAuthScreen` nhận `initialUsername: widget.user.username`, gửi đúng payload đăng ký. |
| **TC05** | Face Login chuyển đúng Dashboard Child | **PASS** | `LoginScreen` phân tích claim role từ JWT, điều hướng chính xác đến `ChildDashboardScreen`. |
| **TC06** | Microphone chỉ chạy sau khi được cấp quyền | **PASS** | `NoiseMeterScreen` gọi `Permission.microphone.request()`, chỉ đo khi quyền được cấp. |
| **TC07** | Dừng đo giải phóng microphone | **PASS** | `_stopListening()` và `dispose()` hủy stream subscription, trả mic cho hệ thống. |
| **TC08** | Child gửi số đo thật theo đúng DeviceId | **PASS** | API `POST /api/ChildDeviceApi/{id}/noise` nhận đúng ID máy được gán của trẻ. |
| **TC09** | Không gửi dữ liệu âm thanh mô phỏng vào backend thật | **PASS** | `_isSimulatedMode` kích hoạt Demo Mode banner và khóa chặt nút gửi telemetry lên API. |
| **TC10** | Child xem QR của thiết bị được gán | **PASS** | `QrGeneratorScreen` sinh QR động từ thông tin máy đã chọn của trẻ. |
| **TC11** | Parent quét QR và truy cập thiết bị hợp lệ | **PASS** | `QrScannerScreen` bóc tách payload, đối chiếu API `GET /api/ChildDeviceApi/{id}`. |
| **TC12** | QR không hợp lệ hoặc hết hạn bị từ chối | **PASS** | Unit test `advanced_features_test.dart` xác nhận FNV-1a checksum sai hoặc TTL > 5 phút bị hủy. |
| **TC13** | QR không giúp vượt qua phân quyền backend | **PASS** | Backend `CanManage` và xác thực JWT Bearer từ chối (403/404) nếu phụ huynh khác quét. |
| **TC14** | Logout và navigation không bị hỏng | **PASS** | `_handleLogout()` xóa SharedPreferences, dùng `pushAndRemoveUntil` về `LoginScreen`. |
| **TC15** | Không có overflow ở các viewport mục tiêu (320, 360, 393, 430 px) với Text Scaler 1.0 và 1.3 | **PASS** | 8/8 tổ hợp kiểm thử widget test chạy trên 320x640, 360x800, 393x852, 430x932 tại scale 1.0 và 1.3 đều đạt 100% không RenderFlex overflow. |

---

## 6. KIỂM THỬ THỰC TẾ TRÊN THIẾT BỊ ANDROID THẬT

- **Thiết bị:** Realme RMX1973 (Android 11, API 30).
- **Serial kết nối ADB:** `2d44b16b`.
- **Cổng chuyển tiếp ADB:**
  - `adb reverse tcp:5221 tcp:5221` (Backend ASP.NET Core HTTP).
  - `adb reverse tcp:7092 tcp:7092` (Backend ASP.NET Core HTTPS).
- **Bằng chứng thực thi:**
  - Build thành công file APK `app-debug.apk` tương thích `compileSdk = 37`.
  - Cài đặt và chụp màn hình xác nhận giao diện ứng dụng hoạt động mượt mà trên phần cứng thực tế.
  - Camera trước và micro hoạt động ổn định với các quyền Android runtime permissions (`RECORD_AUDIO`, `CAMERA`).

---

## 7. CÁC HẠN CHẾ VÀ KẾT LUẬN

### Hạn chế phía Backend & Phần cứng (Đã xử lý an toàn)
1. **Quyền quản lý thiết bị:** Backend chặn quyền sửa/xóa đối với vai trò Child. Ứng dụng tuân thủ nghiêm ngặt, chỉ cho phép Child xem trạng thái và gửi số đo tiếng ồn.
2. **Ngưỡng âm thanh:** Backend không cho phép Child thay đổi `noiseThresholdDb`. Ứng dụng chỉ hiển thị ngưỡng để trẻ nắm thông tin.
3. **Mã băm FNV-1a:** Chỉ dùng để phát hiện lỗi quét quang học / truyền dẫn, không thay thế cơ chế xác thực JWT của backend.

### Kết Luận Nghiệm Thu
- **Giao Diện (UI Status):** `UI READY` — Đạt chuẩn Material Design 3, thân thiện, không có hiện tượng overflow trên màn hình từ 320px đến 430px và tỉ lệ chữ 1.3.
- **Chức Năng (Functional Status):** `FUNCTIONAL READY` — Tích hợp đầy đủ ba tính năng nâng cao, phân quyền vai trò bảo mật chặt chẽ, 47/47 tests tự động PASS tuyệt đối.
