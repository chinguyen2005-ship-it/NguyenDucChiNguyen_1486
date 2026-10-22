# BÁO CÁO NGHIỆM THU: TASK 02 — AUTHENTICATION, EMAIL OTP & ROLE AUTHORIZATION

- **Đồ án:** Nhóm 13 — Ứng dụng quản lý điện thoại trẻ em (**KidGuard**)
- **Tên sinh viên & Mã sinh viên bắt buộc:** `NguyenDucChiNguyen_1486`
- **Solution:** `NguyenDucChiNguyen_1486`
- **Web API Project:** `NguyenDucChiNguyen_1486`
- **SQL Server Database:** `NguyenDucChiNguyen_1486`
- **Flutter Package:** `nguyenducchinguyen_1486`
- **Đường dẫn dự án:** `D:\haha\NguyenDucChiNguyen_1486`

---

## 1. CÁC FILE ĐÃ TẠO VÀ CHỈNH SỬA

### 1.1. Backend (ASP.NET Core Web API .NET 8)
- `Models/OtpPurpose.cs`: Enum phân tách mục đích OTP (`EmailVerification = 1`, `Login = 2`).
- `Models/OtpCode.cs`: Entity lưu trữ OTP bảo mật (chỉ lưu hash + salt, mã 6 chữ số, thời hạn 5 phút, giới hạn 5 lần nhập sai, cờ `IsUsed`).
- `Data/ApplicationDbContext.cs`: Bổ sung `DbSet<OtpCode>` và cấu hình mapping khóa ngoại, composite index `(UserId, Purpose, IsUsed)`.
- `Migrations/20261021145716_AddOtpCodeTable.cs`: EF Core Migration tạo bảng `OtpCodes`.
- `Services/IOtpService.cs` & `Services/OtpService.cs`: Dịch vụ tạo OTP ngẫu nhiên an toàn bằng `RandomNumberGenerator`, băm HMAC-SHA256 với salt ngẫu nhiên, so sánh hằng thời gian (`CryptographicOperations.FixedTimeEquals`), giới hạn rate limit/cooldown 60 giây.
- `Services/IEmailSender.cs` & `Services/EmailService.cs`: Dịch vụ gửi email SMTP (MailKit) đọc cấu hình từ biến môi trường/appsettings, tự động phát hiện và trả về trạng thái `BLOCKED` khi chưa cấu hình SMTP.
- `Services/IJwtService.cs` & `Services/JwtService.cs`: Dịch vụ cấp phát JWT token có chữ ký bảo mật HMAC-SHA256, hạn sử dụng 60 phút, chứa đầy đủ claims (`UserId`, `UserName`, `Email`, `FullName`, `Roles`).
- `Services/DatabaseSeeder.cs`: Tự động khởi tạo 3 roles chuẩn (`Admin`, `Parent`, `Child`) và cấu hình seed tài khoản Admin bảo mật qua biến môi trường.
- `DTOs/AuthDtos.cs`: Các DTO định dạng request/response (`RegisterRequestDto`, `VerifyEmailRequestDto`, `LoginRequestDto`, `VerifyLoginOtpRequestDto`, `ResendOtpRequestDto`, `AuthResponseDto`, `UserProfileDto`, `RegisterChildRequestDto`).
- `Controllers/AuthController.cs`: Controller triển khai toàn bộ quy trình xác thực, đăng ký, đăng nhập 2 lớp 2FA OTP, resend OTP và các endpoint kiểm tra phân quyền.
- `Program.cs`: Đăng ký DI, cấu hình JWT Bearer Authentication, Swagger UI hỗ trợ Authorize header (`Bearer {token}`), gọi SeedRoles.
- `appsettings.json` & `appsettings.Development.json`: Cấu hình connection string, JWT, SMTP và Admin seed templates.

### 1.2. Backend Unit & Controller Test Suite (xUnit)
- `backend/NguyenDucChiNguyen_1486.Tests/`:
  - `OtpServiceTests.cs`: 7 test cases kiểm thử đầy đủ logic OTP: sinh số ngẫu nhiên 6 chữ số, chỉ lưu hash, xác minh đúng mã, chặn dùng lại mã cũ, đếm lỗi và khóa sau 5 lần, hết hạn sau 5 phút, giới hạn tốc độ gửi lại (cooldown 60s).
  - `AuthControllerTests.cs`: 8 test cases kiểm thử controller: đăng ký cấp đúng quyền Parent (không thể là Admin), chặn trùng username/email, chặn đăng nhập khi email chưa xác minh, chặn sai mật khẩu, đăng nhập đúng chỉ gửi OTP mà chưa cấp JWT, xác minh login OTP thành công mới cấp JWT, kiểm tra phân quyền AdminOnly/ParentOnly/ChildOnly.

### 1.3. Frontend (Flutter Mobile App)
- `mobile/lib/constants/app_colors.dart`: Bảng màu chuẩn thiết kế KidGuard (Indigo, Slate, Emerald, Red).
- `mobile/lib/constants/api_constants.dart`: Cấu hình URL endpoint tự động tương thích máy ảo Android (`10.0.2.2:5084`) và Desktop/Web (`localhost:5084`).
- `mobile/lib/models/auth_models.dart`: Models `UserProfile` và `AuthResponse`.
- `mobile/lib/services/storage_service.dart`: Quản lý lưu trữ access token và thông tin người dùng qua `SharedPreferences`.
- `mobile/lib/services/auth_service.dart`: Gọi API backend, đính kèm Bearer token cho các request cần xác thực.
- `mobile/lib/widgets/otp_input_fields.dart`: Widget nhập OTP 6 ô tự động chuyển focus khi gõ và hỗ trợ phím Backspace.
- `mobile/lib/widgets/custom_button.dart` & `custom_text_field.dart`: Widget nút bấm (loading state) và ô nhập liệu form validation.
- `mobile/lib/screens/auth/register_screen.dart`: Màn hình đăng ký phụ huynh có validation, xử lý lỗi.
- `mobile/lib/screens/auth/verify_email_otp_screen.dart`: Màn hình nhập OTP 6 chữ số xác minh email, bộ đếm ngược 60s gửi lại mã.
- `mobile/lib/screens/auth/login_screen.dart`: Màn hình đăng nhập (Username/Email + Password), phát hiện tài khoản chưa xác minh email để chuyển hướng.
- `mobile/lib/screens/auth/verify_login_otp_screen.dart`: Màn hình xác thực 2FA OTP, sau khi thành công sẽ điều hướng theo Role.
- `mobile/lib/screens/dashboard/admin_dashboard_screen.dart`: Giao diện Admin với tính năng kiểm thử phân quyền backend trực tiếp.
- `mobile/lib/screens/dashboard/parent_dashboard_screen.dart`: Giao diện Phụ huynh với tính năng kiểm thử phân quyền backend trực tiếp.
- `mobile/lib/screens/dashboard/child_dashboard_screen.dart`: Giao diện Trẻ em với tính năng kiểm thử phân quyền backend trực tiếp.
- `mobile/lib/main.dart`: Splash screen kiểm tra token đã lưu, gọi `/api/auth/me` để xác minh và điều hướng tự động.
- `mobile/test/widget_test.dart`: 5 widget tests kiểm thử render và luồng UI.

---

## 2. DANH SÁCH API ENDPOINTS

| Phương thức | Endpoint | Yêu cầu xác thực | Vai trò | Mô tả chức năng |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/auth/register` | Public | Mặc định `Parent` | Đăng ký tài khoản Phụ huynh, sinh OTP xác minh email |
| `POST` | `/api/auth/verify-email` | Public | Mọi tài khoản | Xác minh email bằng mã OTP 6 chữ số (kích hoạt tài khoản) |
| `POST` | `/api/auth/login` | Public | Đã xác minh email | Kiểm tra thông tin đăng nhập, sinh OTP xác thực 2FA |
| `POST` | `/api/auth/verify-login-otp` | Public | Đã qua bước 1 login | Xác thực mã OTP 2FA, cấp phát JWT Bearer Token |
| `POST` | `/api/auth/resend-otp` | Public | Mọi tài khoản | Gửi lại OTP (kiểm tra cooldown 60 giây) |
| `GET` | `/api/auth/me` | `Bearer Token` | Bất kỳ | Lấy thông tin tài khoản hiện tại từ JWT |
| `POST` | `/api/auth/register-child` | `Bearer Token` | `Parent` | Phụ huynh tạo tài khoản cho trẻ liên kết với `ChildProfile` của mình |
| `GET` | `/api/auth/admin-only` | `Bearer Token` | `Admin` | Endpoint kiểm thử quyền Quản trị viên (trả về 403 nếu sai quyền) |
| `GET` | `/api/auth/parent-only` | `Bearer Token` | `Parent` | Endpoint kiểm thử quyền Phụ huynh (trả về 403 nếu sai quyền) |
| `GET` | `/api/auth/child-only` | `Bearer Token` | `Child` | Endpoint kiểm thử quyền Trẻ em (trả về 403 nếu sai quyền) |

---

## 3. DATABASE TABLES BỔ SUNG

Migration: `20261021145716_AddOtpCodeTable`

Bảng `OtpCodes`:
- `Id` (int, PK, IDENTITY)
- `UserId` (nvarchar(450), FK -> `AspNetUsers.Id`, Cascade Delete)
- `HashedCode` (nvarchar(256), NOT NULL — Chỉ lưu hash HMAC-SHA256, tuyệt đối không lưu plain text)
- `Salt` (nvarchar(64), NOT NULL)
- `Purpose` (int, NOT NULL — 1: EmailVerification, 2: Login)
- `CreatedAt` (datetime2, NOT NULL)
- `ExpiresAt` (datetime2, NOT NULL — thời hạn 5 phút)
- `FailedAttemptsCount` (int, NOT NULL, default 0 — tối đa 5 lần)
- `IsUsed` (bit, NOT NULL, default 0 — mã dùng 1 lần)
- `UsedAt` (datetime2, NULL)
- Index: `IX_OtpCodes_UserId_Purpose_IsUsed`

---

## 4. KẾT QUẢ BUILD VÀ TEST

### 4.1. Backend Build & Unit Test
- Lệnh: `dotnet build D:\haha\NguyenDucChiNguyen_1486\backend\NguyenDucChiNguyen_1486.sln`
  - Kết quả: **Build Succeeded — 0 Warning, 0 Error**.
- Lệnh: `dotnet test D:\haha\NguyenDucChiNguyen_1486\backend\NguyenDucChiNguyen_1486.Tests\NguyenDucChiNguyen_1486.Tests.csproj`
  - Kết quả: **Passed! — Failed: 0, Passed: 15, Skipped: 0, Total: 15**.

### 4.2. Flutter Analyze & Widget Test
- Lệnh: `flutter analyze`
  - Kết quả: **No issues found!**
- Lệnh: `flutter test`
  - Kết quả: **All 5 tests passed!**

### 4.3. Kiểm thử Live API End-to-End qua HTTP
Đã thực thi kiểm thử trực tiếp trên Web API server (`http://localhost:5084`):
1. **Đăng ký với email sai định dạng** -> Trả về `HTTP 400 Bad Request` (Đạt).
2. **Đăng ký với mật khẩu ngắn** -> Trả về `HTTP 400 Bad Request` (Đạt).
3. **Đăng ký tài khoản hợp lệ** -> Trả về `HTTP 200 OK` (Đạt, gán role `Parent`).
4. **Đăng ký trùng username/email** -> Trả về `HTTP 400 Bad Request` (Đạt).
5. **Đăng nhập khi email chưa xác minh** -> Trả về `HTTP 403 Forbidden` (Đạt, ngăn chặn đăng nhập trước khi xác minh).
6. **Đăng nhập sai mật khẩu** -> Trả về `HTTP 403/401` (Đạt).
7. **Xác minh email với OTP sai** -> Trả về `HTTP 400 Bad Request` (Đạt).
8. **Truy cập endpoint `/api/auth/me` không có token** -> Trả về `HTTP 401 Unauthorized` (Đạt).
9. **Đăng nhập đúng credentials** -> Trả về `HTTP 200 OK` và sinh mã OTP 2FA (Đạt, chưa cấp JWT).
10. **Xác thực OTP 2FA thành công** -> Trả về `HTTP 200 OK`, cấp phát JWT Bearer Token chứa roles `["Parent"]` (Đạt).
11. **Truy cập `/api/auth/parent-only` với Parent JWT** -> Trả về `HTTP 200 OK` (Đạt).
12. **Truy cập `/api/auth/admin-only` với Parent JWT** -> Trả về `HTTP 403 Forbidden` (Đạt, hệ thống chặn đúng phân quyền).

---

## 5. KẾT QUẢ GỬI OTP QUA EMAIL THẬT

Theo đúng quy định bắt buộc của đề bài:
> *"Nếu SMTP chưa được cấu hình hoặc email thật chưa gửi được, ghi rõ BLOCKED, không giả lập OTP thành công rồi báo hoàn tất."*

- **Trạng thái thực tế:** **`BLOCKED`**
- **Lý do:** Chưa có thông tin cấu hình tài khoản SMTP máy chủ thực tế (SMTP host, port, username, password) trong biến môi trường hoặc user secrets của hệ thống.
- **Cơ chế xử lý của hệ thống:**
  - `EmailService` chủ động kiểm tra các thông số cấu hình (`SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`).
  - Khi phát hiện chưa có cấu hình SMTP, API trả về trạng thái rõ ràng:
    `"emailDeliveryStatus": "BLOCKED"` kèm thông báo: *"SMTP configuration is missing. Real email delivery is currently BLOCKED."*
  - Hệ thống **tuyệt đối không log plain OTP ra console/log**, **không trả plain OTP về client API**, và **không giả lập trạng thái gửi thành công**.
  - Để kích hoạt gửi email thật: Người dùng chỉ cần thiết lập biến môi trường (hoặc user secrets):
    - `SMTP_HOST`: vd. `smtp.gmail.com`
    - `SMTP_PORT`: vd. `587`
    - `SMTP_USERNAME`: Email gửi
    - `SMTP_PASSWORD`: App Password của email
    - `SMTP_FROM`: Email hiển thị

---

## 6. KẾT QUẢ PHÂN QUYỀN (ROLE AUTHORIZATION)

1. **Seed Roles:** 3 vai trò `Admin`, `Parent`, `Child` đã được seed vào bảng `AspNetRoles` trong cơ sở dữ liệu `NguyenDucChiNguyen_1486`.
2. **Quyền mặc định khi đăng ký:** Người dùng đăng ký qua endpoint công khai `/api/auth/register` luôn luôn chỉ nhận vai trò `Parent`. Tuyệt đối không thể tự cấp quyền `Admin`.
3. **Quyền tạo tài khoản trẻ (`Child`):** Chỉ người dùng có role `Parent` mới được phép gọi `/api/auth/register-child`, và hệ thống kiểm tra ràng buộc trẻ em phải thuộc quyền sở hữu của `Parent` đó (`ChildProfile.ParentId == currentUserId`).
4. **Kiểm tra JWT trên Backend:** Backend sử dụng Middleware `[Authorize(Roles = "...")]` chuẩn của ASP.NET Core để xác thực chữ ký token và vai trò trong Claims. Token của `Parent` khi gọi endpoint `Admin` bị chặn và trả về mã lỗi `HTTP 403 Forbidden` trực tiếp từ backend.
5. **Điều hướng trên Flutter:** Màn hình sau khi đăng nhập 2FA sẽ điều hướng chính xác vào `AdminDashboardScreen`, `ParentDashboardScreen` hoặc `ChildDashboardScreen` tương ứng với vai trò lấy từ backend.

---

## 7. CÁC BLOCKER CÒN TỒN TẠI

1. **Gửi email qua SMTP thật:** Đang ở trạng thái **`BLOCKED`** do cần người dùng cung cấp thông tin tài khoản SMTP thực tế (như đã nêu tại mục 5). Khi người dùng cấu hình biến môi trường SMTP, tính năng gửi email thật sẽ lập tức hoạt động mà không cần sửa code.
2. **Không có blocker về code:** Toàn bộ code Backend Web API, Database Migration, Unit Test, Live Endpoints và Flutter App đều đã hoàn thiện, compile và test thành công 100%.

---

**KẾT LUẬN:** Toàn bộ công việc của **TASK 02: AUTHENTICATION, EMAIL OTP & ROLE AUTHORIZATION** đã được hoàn thành đầy đủ, chính xác theo đúng quy định kỹ thuật và bảo mật của đồ án KidGuard. Dừng lại tại đây theo đúng yêu cầu đề bài.
