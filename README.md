# KidGuard — Ứng Dụng Giám Sát & Bảo Vệ Điện Thoại Trẻ Em (Nhóm 13)

**Học phần:** Xây dựng ứng dụng di động  
**Sinh viên thực hiện:** Nguyễn Đức Chí Nguyên (`NguyenDucChiNguyen_1486`)  
**Repository cá nhân (Public):** [https://github.com/chinguyen2005-ship-it/NguyenDucChiNguyen_1486](https://github.com/chinguyen2005-ship-it/NguyenDucChiNguyen_1486)  

---

## 1. Giới Thiệu Dự Án

**KidGuard** là giải pháp quản lý và bảo vệ thiết bị di động của trẻ em, xây dựng trên mô hình phân quyền chặt chẽ giữa **Phụ huynh (Parent)**, **Trẻ em (Child)** và **Quản trị viên (Admin)**.

### Hồ Sơ & Mã Nguồn Trong Repository Này
- **Báo cáo nộp bài chính thức (`NguyenDucChiNguyen_1486.docx`)**: Báo cáo tổng kết đồ án học phần của sinh viên Nguyễn Đức Chí Nguyên đặt tại thư mục gốc repository.
- **Mã nguồn ứng dụng (`mobile/`)**: Ứng dụng di động đa nền tảng Flutter Client do sinh viên Nguyễn Đức Chí Nguyên phát triển, tích hợp toàn bộ các tính năng phân quyền vai trò, quản lý thiết bị trẻ em, giám sát mức tiếng ồn, sinh trắc học khuôn mặt Face AI, quét mã QR và tính năng sáng tạo **Góc An Toàn Gia Đình (KidGuard Safety Insights)**.
- **Tài liệu kiểm thử & báo cáo chi tiết (`docs/`)**: Toàn bộ tài liệu phân tích kỹ thuật, báo cáo phân quyền, nhật ký kiểm thử CRUD và báo cáo triển khai.
- **Backend chung của Nhóm 13 (`backend-group/`)**: **KHÔNG NẰM TRONG REPOSITORY NÀY** nhằm tuân thủ quy định bảo mật, bản quyền mã nguồn backend của nhóm và tránh lộ cấu hình máy chủ/CSDL dùng chung.

---

## 2. Kiến Trúc Ứng Dụng & Phân Quyền

```
┌────────────────────────────────────────────────────────┐
│                   KidGuard Mobile App                  │
│                     (Flutter Client)                   │
└──────────────┬───────────────────────────┬─────────────┘
               │ HTTPS RESTful API         │ JWT Auth
               ▼                           ▼
┌────────────────────────────────────────────────────────┐
│               KidGuard ASP.NET Core API                │
│                 (Backend Nhóm 13)                      │
├────────────────────────────────────────────────────────┤
│ • Phân quyền Identity (Admin / Parent / Child)         │
│ • Quản lý thiết bị con & Cảnh báo tiếng ồn             │
│ • Xác thực 2 bước (2FA OTP qua Gmail SMTP)             │
│ • Trích xuất đặc trưng khuôn mặt ArcFace (ONNX)        │
│ • CSDL SQL Server (Code-First Migrations)              │
└────────────────────────────────────────────────────────┘
```

### Các Vai Trò Trong Ứng Dụng:
- **Phụ huynh (Parent)**: Quản lý danh sách thiết bị con, cấu hình ngưỡng tiếng ồn an toàn (dB), xem lịch sử đo từ thiết bị con, nhận cảnh báo vượt ngưỡng, truy cập *Góc An Toàn Gia Đình* và đăng ký Face AI cá nhân.
- **Trẻ em (Child)**: Giao diện trực quan cho trẻ, đo mức độ tiếng ồn thực tế quanh thiết bị, gửi dữ liệu telemetry kèm cảnh báo tự động về cho cha mẹ, hiển thị mã QR định danh thiết bị.
- **Quản trị viên (Admin)**: Quản lý danh mục tài khoản, giám sát toàn hệ thống, xác minh kỹ thuật phân quyền JWT.

---

## 3. Hướng Dẫn Cài Đặt & Chạy Ứng Dụng Flutter (`mobile/`)

### Yêu Cầu Môi Trường
- **Flutter SDK**: `>= 3.13.3` (khuyến nghị Flutter 3.24 trở lên)
- **Dart SDK**: `>= 3.5.0`
- **Android SDK**: API Level 34+
- **Thiết bị**: Android Emulator hoặc điện thoại thật Android (Android 10+)

### Các Bước Khởi Chạy:
1. **Di chuyển vào thư mục ứng dụng Flutter:**
   ```bash
   cd mobile
   ```

2. **Cài đặt các gói phụ thuộc:**
   ```bash
   flutter pub get
   ```

3. **Kiểm tra phân tích tĩnh mã nguồn:**
   ```bash
   flutter analyze
   ```

4. **Chạy toàn bộ bộ kiểm thử tự động (105 test cases):**
   ```bash
   flutter test
   ```

5. **Khởi chạy ứng dụng lên thiết bị:**
   ```bash
   flutter run
   ```

---

## 4. Cấu Hình Địa Chỉ API Backend

Tệp cấu hình tập trung tọa lạc tại: `mobile/lib/constants/api_constants.dart`.

### Chế Độ 1: Kết Nối Máy Chủ Cloud (Mặc định)
Hệ thống mặc định kết nối đến máy chủ backend đã được triển khai sẵn trên môi trường điện toán đám mây:
```dart
static const String cloudBaseUrl = 'https://nhiemhotdcm-001-site1.htempurl.com';
static const bool useCloudServer = true;
```
*Khi bật chế độ này, bạn có thể chạy app ngay lập tức từ bất kỳ mạng Wi-Fi/4G nào mà không cần khởi động backend cục bộ.*

### Chế Độ 2: Kết Nối Backend Cục Bộ (Localhost Development)
Nếu bạn có mã nguồn `backend-group` từ nhóm và muốn chạy backend nội bộ trên máy:
1. Đổi cờ cấu hình trong `mobile/lib/constants/api_constants.dart`:
   ```dart
   static const bool useCloudServer = false;
   ```
2. Khởi chạy backend ASP.NET Core từ thư mục backend nhóm:
   ```bash
   dotnet run --urls "http://127.0.0.1:5221;https://127.0.0.1:7092"
   ```

---

## 5. Kết Nối Thiết Bị Thật & Giả Lập Android

### Kết Nối Điện Thoại Thật Qua Cáp USB (Chế độ Localhost):
Khi chạy backend trên máy tính và app trên điện thoại thật cắm cáp USB, chuyển tiếp cổng kết nối qua ADB:
```bash
adb reverse tcp:7092 tcp:7092
adb reverse tcp:5221 tcp:5221
```
*Lưu ý: Ứng dụng đã tích hợp sẵn chứng chỉ tự ký `DevHttpOverrides` trong môi trường phát triển để hỗ trợ HTTPS nội bộ mượt mà.*

### Kết Nối Máy Ảo Android Emulator:
- Sử dụng địa chỉ mặc định của Android Emulator `10.0.2.2` hoặc giữ nguyên `127.0.0.1` kèm lệnh `adb reverse`.

---

## 6. Tính Năng Sáng Tạo: Góc An Toàn Gia Đình (KidGuard Safety Insights)

Nhằm đáp ứng tiêu chí 1 điểm sáng tạo trong đề bài, ứng dụng phát triển phân hệ **Góc An Toàn Gia Đình** với các tính năng vượt trội so với danh sách CRUD thông thường:
- **Chỉ Số An Toàn Tổng Thể (Safety Score 0–100%)**: Thuật toán phân tích tổng hợp dữ liệu pin, trạng thái khóa, mức độ tiếng ồn và cảnh báo vượt ngưỡng.
- **Bộ Lọc Thiết Bị & Thời Gian Linh Hoạt**: Lọc nhanh theo từng con hoặc khung thời gian (Hôm nay / 7 ngày / 30 ngày).
- **Phân Tích Xu Hướng Tiếng Ồn (Noise Trend Chart)**: Trực quan hóa các khung giờ ồn ào bất thường bằng biểu đồ cột tương tác màu sắc.
- **Gợi Ý Hành Động Thông Minh**: Hệ thống tự động đề xuất giải pháp khi phát hiện thiết bị pin yếu, tiếng ồn cao kéo dài hoặc thiết bị mất kết nối.

---

## 7. Báo Cáo & Tài Liệu Kiểm Thử Chi Tiết

Toàn bộ tài liệu đặc tả, ma trận kiểm thử và biên bản nghiệm thu được lưu trữ trong thư mục `docs/`:
- [TASK_02_AUTH_REPORT.md](docs/TASK_02_AUTH_REPORT.md): Xác thực 2 bước (2FA OTP), đăng ký, đăng nhập & phân quyền Identity.
- [TASK_03_CRUD_AUDIT.md](docs/TASK_03_CRUD_AUDIT.md) & [TASK_03_1_FLUTTER_CRUD_REPORT.md](docs/TASK_03_1_FLUTTER_CRUD_REPORT.md): Nghiệm thu CRUD thiết bị trẻ em.
- [TASK_04_1_CHILD_ROLE_REPORT.md](docs/TASK_04_1_CHILD_ROLE_REPORT.md): Kiểm thử vai trò Child & ngăn chặn leo thang đặc quyền.
- [TASK_04_3_CHILD_ACCOUNT_REPORT.md](docs/TASK_04_3_CHILD_ACCOUNT_REPORT.md): Tạo tài khoản con phụ thuộc dành cho Phụ huynh.
- [TASK_04_4_REMOTE_NOISE_FEASIBILITY.md](docs/TASK_04_4_REMOTE_NOISE_FEASIBILITY.md): Khảo sát và phân tách quyền đo tiếng ồn từ xa.
- [TASK_04_5_PARENT_DASHBOARD_REPORT.md](docs/TASK_04_5_PARENT_DASHBOARD_REPORT.md): Tái thiết kế bảng điều khiển Phụ huynh chuẩn UX.
- [TASK_05_2_SAFETY_INSIGHTS_REPORT.md](docs/TASK_05_2_SAFETY_INSIGHTS_REPORT.md): Phân hệ sáng tạo KidGuard Safety Insights.
- [TASK_CLOUD_DEPLOYMENT_VERIFICATION_REPORT.md](docs/TASK_CLOUD_DEPLOYMENT_VERIFICATION_REPORT.md): Kiểm thử hệ thống với máy chủ điện toán đám mây.
- [GITHUB_PUBLIC_PRE_PUSH_AUDIT.md](docs/GITHUB_PUBLIC_PRE_PUSH_AUDIT.md): Biên bản rà soát bảo mật trước khi công khai repository.

---

## 8. Video Minh Họa (Demo Video)
- **Tập tin video thực tế:** `Demo.mp4` (~601 MB) quay lại toàn bộ quy trình vận hành ứng dụng trên máy thật (2FA OTP, đo mức độ tiếng ồn, quét mã QR, đồng bộ thời gian thực qua Cloud).
- **Lưu ý lưu trữ:** Do chính sách của GitHub giới hạn dung lượng tải lên tối đa **100 MB** cho mỗi tệp tin đơn lẻ (`remote: error: GH001: Large files detected`), tệp tin video dung lượng lớn được lưu trữ riêng và đính kèm liên kết Drive trong hồ sơ nộp bài.
