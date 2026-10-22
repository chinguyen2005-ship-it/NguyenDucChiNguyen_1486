# BÁO CÁO TASK 04.3: QUẢN LÝ TÀI KHOẢN TRẺ EM (CHILD ACCOUNT MANAGEMENT)
**Dự án:** KidGuard — Quản Lý Điện Thoại Trẻ Em (Nhóm 13)  
**Sinh viên thực hiện:** Nguyễn Đức Chí Nguyên (MSSV: 1486)  
**Ngày báo cáo:** 22/10/2026  
**Môi trường:** Flutter 3.32+ (Dart 3.8+), ASP.NET Core 9.0 Web API, SQL Server 2022  
**Thiết bị thực tế kiểm thử:** Realme RMX1973 (Android 11, API 30, Chip Snapdragon 712)  

---

## 1. KIỂM TRA TOÀN DIỆN BACKEND & GIỚI HẠN HIỆN CÓ

Thực hiện kiểm tra trực tiếp mã nguồn backend chung trong `backend-group/nhom13/` theo nguyên tắc **READ-ONLY tuyệt đối**:

### A. Endpoint Đăng Ký Tài Khoản (`AuthenticateController.cs`)
- **Endpoint:** `POST /api/Authenticate/register`
- **Payload (`RegisterModel.cs`):**
  ```csharp
  public class RegisterModel
  {
      public string? Username { get; set; }
      public string? Email { get; set; }
      public string? Password { get; set; }
      public string? FullName { get; set; }
      public string? Role { get; set; } // Hỗ trợ Role
  }
  ```
- **Xác thực Role:**
  ```csharp
  // AuthenticateController.cs (dòng 52-60)
  var requestedRole = string.IsNullOrWhiteSpace(model.Role) ? "Parent" : model.Role.Trim();
  if (requestedRole.Equals("Admin", StringComparison.OrdinalIgnoreCase))
  {
      return StatusCode(StatusCodes.Status403Forbidden, 
          new Response { Status = "Error", Message = "Không được phép đăng ký vai trò Admin." });
  }
  ```
  - Mặc định nếu không truyền `Role`: Tạo tài khoản vai trò `"Parent"`.
  - Nếu truyền `Role: "Child"`: Backend **CHẤP NHẬN** và tạo tài khoản với vai trò `"Child"`.
  - Nếu truyền `Role: "Admin"`: Backend **TỪ CHỐI** bằng mã HTTP `403 Forbidden`.
  - **Cơ chế xác thực bắt buộc:** Sau khi đăng ký, tài khoản chưa được kích hoạt ngay (`EmailConfirmed = false`). Hệ thống gửi mã OTP 6 chữ số qua Email và yêu cầu gọi `POST /api/Authenticate/confirm-email-register`.

### B. Parent Có Thể Tự Tạo Tài Khoản Child Dưới Quyền Của Mình Không?
- **BLOCKER BACKEND:** Trong toàn bộ các Controller backend (`AuthenticateController`, `ParentController`, `ChildDeviceApiController`), **KHÔNG CÓ endpoint nào** cho phép Phụ huynh đang đăng nhập (`[Authorize(Roles = "Parent")]`) trực tiếp khởi tạo một tài khoản con mà không cần email OTP độc lập.
- Không có bảng cơ sở dữ liệu `ParentChild` hay quan hệ trực tiếp 1-N giữa tài khoản `Parent` và tài khoản `Child` trong ASP.NET Core Identity.

### C. Admin Có Thể Đổi Role Tài Khoản Thành Child Không? (`AdminController.cs`)
- **CÓ HỖ TRỢ ĐẦY ĐỦ:**
  - `GET /api/Admin/users?search=...`: Lấy danh sách toàn bộ người dùng, bao gồm thông tin `roles`, `hasFace`, `isLockedOut`, `emailConfirmed`.
  - `PUT /api/Admin/users/{username}/role`: Cho phép Admin đổi role của bất kỳ user nào sang `"Child"`, `"Parent"`, hoặc `"Admin"`.
  - `PUT /api/Admin/users/{username}/unlock`: Cho phép Admin mở khóa tài khoản bị lockout.

### D. Parent Có Thể Gán `ChildUsername` Khi Thêm/Sửa Thiết Bị Không?
- **CÓ HỖ TRỢ & CÓ VALIDATION CHẶT CHẼ:**
  - `POST /api/ChildDeviceApi` và `PUT /api/ChildDeviceApi/{id}` nhận trường `ChildUsername`.
  - Backend thực hiện hàm kiểm tra tính hợp lệ `ValidateChildUsernameAsync`:
    ```csharp
    // ChildDeviceApiController.cs (dòng 239-251)
    private async Task<bool> ValidateChildUsernameAsync(string? childUsername)
    {
        if (string.IsNullOrWhiteSpace(childUsername)) return true;
        var user = await _userManager.FindByNameAsync(childUsername.Trim());
        if (user == null) return false;
        var roles = await _userManager.GetRolesAsync(user);
        return roles.Any(r => r.Equals("Child", StringComparison.OrdinalIgnoreCase));
    }
    ```
  - Nếu Phụ huynh nhập một username không tồn tại trong hệ thống, hoặc username đó mang Role `Parent` hay `Admin`, backend trả về mã lỗi HTTP `400 Bad Request` kèm thông báo: *"Tài khoản trẻ em không hợp lệ hoặc không có quyền Child"*.

### E. Quan Hệ Gia Đình Được Lưu Trữ Như Thế Nào?
- Backend **chỉ liên kết Parent và Child thông qua Thiết Bị** (`ChildDevice.ParentUsername` và `ChildDevice.ChildUsername`).
- Không có bảng phân cấp gia đình riêng biệt. Do đó, việc liên kết `@childUsername` vào thiết bị chính là cơ chế duy nhất backend hỗ trợ để gán quyền quản lý của Parent đối với Child.

---

## 2. QUY TRÌNH QUẢN LÝ & TẠO TÀI KHOẢN TRẺ EM KHẢ THI

Dựa trên kết quả audit backend thực tế, ứng dụng Flutter triển khai quy trình chuẩn xác 100% theo API thật, tuyệt đối không giả lập dữ liệu:

```
+-----------------------------------------------------------------------------------+
|                           QUY TRÌNH HỢP LỆ VỚI BACKEND HIỆN CÓ                    |
+-----------------------------------------------------------------------------------+
|                                                                                   |
|  [Quy trình 1: Tự đăng ký Role Child qua OTP]                                    |
|  1. Mở màn hình Đăng ký (RegisterScreen).                                         |
|  2. Chọn SegmentedButton: "Trẻ Em (Child)".                                       |
|  3. Nhập Username trẻ, Email nhận OTP, Mật khẩu.                                  |
|  4. Xác thực mã OTP 6 chữ số gửi về Email.                                       |
|  5. Tài khoản kích hoạt thành công với Role = "Child".                            |
|                                                                                   |
|  [Quy trình 2: Quản trị viên (Admin) phân quyền]                                 |
|  1. Admin đăng nhập vào AdminDashboardScreen.                                     |
|  2. Vào "Quản Lý Người Dùng & Phân Quyền".                                       |
|  3. Tìm tài khoản người dùng -> Bấm "Đổi vai trò" -> Chọn "Child".                |
|  4. Gọi PUT /api/Admin/users/{username}/role -> Thành công.                       |
|                                                                                   |
|  [Liên kết Parent -> Child -> Device]                                            |
|  1. Phụ huynh mở ParentDashboardScreen -> Thấy mục "Quản Lý Trẻ Em".              |
|  2. Bấm "Thêm / Liên kết" -> Chọn "Gán Tài Khoản Trẻ Vào Thiết Bị".              |
|  3. Trong DeviceFormScreen, nhập @childUsername đã tạo ở bước trên.               |
|  4. Backend ValidateChildUsernameAsync: Xác nhận hợp lệ (HTTP 200).               |
|  5. Thiết bị được gán cho Child.                                                  |
|  6. Trẻ đăng nhập vào ChildDashboard -> Thấy đúng thiết bị và tính năng nâng cao. |
+-----------------------------------------------------------------------------------+
```

---

## 3. CÁC MÀN HÌNH ĐÃ TRIỂN KHAI TRONG FLUTTER

### A. Mục "Quản Lý Trẻ Em" Trên `ParentDashboardScreen`
- **Vị trí:** Đặt ngay sau khu vực thống kê tổng quan và tính năng nâng cao.
- **Thống kê 3 cột responsive:**
  1. *Thiết bị con* (`_devices.length`)
  2. *Đang khóa* (`lockedCount`)
  3. *Trẻ em* (`_groupedChildren.length`)
- **Nhóm dữ liệu thông minh (`_ChildAccountGroup`):**
  - Tự động nhóm các thiết bị theo tài khoản con (`childUsername`) hoặc tên trẻ (`childName`).
  - Hiển thị CircleAvatar chữ cái đầu của trẻ.
  - **Trạng thái liên kết tài khoản:**
    - Nếu đã gán username: Huy hiệu xanh `Role: Child` kèm `@childUsername` đã xác minh.
    - Nếu chưa gán: Cảnh báo màu hổ phách *"Chưa liên kết tài khoản con"*, kèm nút sửa nhanh.
  - **Danh sách thiết bị được gán:** Hiển thị dạng Chip kèm biểu tượng khóa/mở và tên model. Bấm vào thiết bị chuyển ngay sang `DeviceDetailScreen`.
  - **Nút "Thêm / Liên kết":** Mở Bottom Sheet modal gồm 3 tùy chọn:
    1. *Gán Tài Khoản Trẻ Vào Thiết Bị:* Mở CRUD thiết bị để nhập `@childUsername`.
    2. *Đăng Ký Tài Khoản Cho Trẻ:* Điều hướng sang `RegisterScreen(initialRole: 'Child')`.
    3. *Quy Trình & Hướng Dẫn Role Child:* Dialog giải thích rõ ràng cơ chế phân quyền backend.

### B. Hỗ Trợ Đăng Ký Role Child Trên `RegisterScreen`
- Thêm tham số `initialRole` (mặc định `'Parent'`, hỗ trợ khởi tạo trực tiếp `'Child'`).
- Bổ sung `SegmentedButton<String>` cho phép chuyển đổi mượt mà giữa **Phụ Huynh** và **Trẻ Em**.
- Nhãn hiển thị tự động thay đổi theo ngữ cảnh (`Họ và tên trẻ em` / `Email trẻ em` vs `Họ và tên phụ huynh` / `Email phụ huynh`).
- Gọi đúng API `POST /api/Authenticate/register` với `Role: _selectedRole`.

### C. Màn Hình Quản Trị Viên Phân Quyền (`AdminUserManagementScreen`)
- **Tích hợp:** Nút truy cập từ `AdminDashboardScreen`.
- **Chức năng:**
  - Tìm kiếm người dùng theo username/email thời gian thực.
  - Hiển thị danh sách người dùng với role badge (Đỏ: Admin, Xanh lam: Parent, Xanh ngọc: Child).
  - Trạng thái xác thực Email (`EmailConfirmed`) và Face AI (`hasFace`).
  - Huy hiệu cảnh báo nếu tài khoản đang bị khóa (`Bị khóa`).
  - Hộp thoại **"Đổi Vai Trò Người Dùng"** sử dụng `RadioGroup`:
    - `Child (Trẻ em)`: Có thể gán vào thiết bị giám sát KidGuard.
    - `Parent (Phụ huynh)`: Quản lý thiết bị con và cấu hình an toàn.
    - `Admin (Quản trị viên)`: Toàn quyền quản lý hệ thống.
  - Gọi API `PUT /api/Admin/users/{username}/role` và `PUT /api/Admin/users/{username}/unlock`.

---

## 4. AN TOÀN & BẢO MẬT (SECURITY COMPLIANCE)

1. **Không bypass quyền:** Flutter không tự sinh JWT hay tự đổi role cục bộ. Mọi quyền truy cập phụ thuộc 100% vào Token do ASP.NET Core Identity cấp phát.
2. **Kiểm tra chéo gia đình:**
   - Khi Parent truy vấn `GET /api/ChildDeviceApi`, backend tự lọc theo `ParentUsername = current_user`. Phụ huynh không thể xem thiết bị của gia đình khác.
   - Khi Child truy vấn `GET /api/ChildDeviceApi`, backend lọc theo `ChildUsername = current_user`. Trẻ em chỉ xem được thiết bị được gán cho chính mình.
3. **Mật khẩu an toàn:** Không lưu trữ mật khẩu plaintext; toàn bộ truyền qua HTTPS/HTTP và được ASP.NET Core băm bằng PBKDF2 with HMAC-SHA256.
4. **Validation phía Client & Server:** Nếu nhập username không tồn tại hoặc không phải Role `Child`, backend từ chối với HTTP 400. Flutter bắt lỗi và hiển thị rõ ràng trên giao diện.

---

## 5. KẾT QUẢ KIỂM THỬ THỰC TẾ

### A. Kiểm Thử Tự Động (Widget & Unit Tests)
- **Tập tin test mới:** `mobile/test/child_account_test.dart`
  - `AdminUserModel Serialization & Role Helpers Tests`: 2/2 passed.
  - `RegisterScreen Role Selection Tests`: 1/1 passed.
  - `ParentDashboardScreen Child Account Management Section Tests`: 2/2 passed.
  - `Responsive Viewport Tests (320x640, 360x800, 393x852, 430x932 tại font scale 1.0 & 1.3)`: 4/4 passed (0 lỗi RenderFlex overflow).
- **Hồi quy toàn bộ dự án (`flutter test`):**
  - `test/advanced_features_test.dart`: 13/13 passed.
  - `test/child_dashboard_test.dart`: 8/8 passed.
  - `test/device_crud_test.dart`: 23/23 passed.
  - `test/child_account_test.dart`: 9/9 passed.
  - `test/widget_test.dart`: 3/3 passed.
  - **Tổng cộng:** **56/56 tests passed (100%)**.
- **Static Analysis (`flutter analyze`):**
  - **0 issues found.** Không có lỗi cú pháp, cảnh báo hay linter vi phạm.

---

## 6. BACKEND BLOCKER & ĐỀ XUẤT NÂNG CẤP DÀNH CHO NHÓM BACKEND

Hiện tại để có tài khoản Child, trẻ bắt buộc phải có Email riêng để nhận OTP, hoặc Admin phải đổi role thủ công. Đây là một rào cản trải nghiệm lớn đối với trẻ em nhỏ tuổi chưa có email.

### Đề Xuất Bổ Sung Cho Backend Nhóm:
1. **Endpoint Parent tạo trực tiếp tài khoản Child:**
   - `POST /api/Parent/children`
   - **Authorization:** `[Authorize(Roles = "Parent")]`
   - **Request Body:**
     ```json
     {
       "username": "be_bap",
       "fullName": "Nguyễn Văn Bắp",
       "password": "Password123@",
       "birthDate": "2018-05-10"
     }
     ```
   - **Xử lý Backend:**
     - Tự động gán Role `Child`.
     - Tự động đánh dấu `EmailConfirmed = true` (không cần OTP email).
     - Tự động lưu bản ghi quan hệ vào bảng `ParentChildren(ParentId, ChildId, CreatedAt)`.
2. **Endpoint lấy danh sách trẻ em của Parent:**
   - `GET /api/Parent/children`
   - Trả về danh sách hồ sơ con em kèm danh sách thiết bị liên kết, giúp Parent quản lý độc lập mà không cần suy diễn từ thiết bị.

---

## 7. HƯỚNG DẪN DEMO TỪNG BƯỚC (PARENT → CHILD → DEVICE)

### Bước 1: Tạo Tài Khoản Trẻ Em (Role Child)
- Tại màn hình Đăng Nhập, bấm **"Đăng ký ngay"**.
- Tại `RegisterScreen`, bấm chọn nút chuyển đổi **"Trẻ Em"**.
- Nhập thông tin:
  - Họ và tên: `Bé Bắp`
  - Tên đăng nhập: `be_bap`
  - Email: Nhập email nhận OTP (ví dụ: `bebap@example.com`)
  - Mật khẩu: `BeBap@123`
- Bấm **"Đăng Ký & Nhận Mã OTP"** -> Nhập mã 6 số nhận từ email -> Kích hoạt thành công.

*(Cách thay thế nhanh với Admin)*:
- Đăng nhập với tài khoản Admin (`admin`).
- Vào **"Quản Lý Người Dùng & Phân Quyền"**.
- Tìm user bất kỳ -> Bấm **"Đổi vai trò"** -> Chọn **"Child"** -> Lưu.

### Bước 2: Phụ Huynh Gán Tài Khoản Trẻ Vào Thiết Bị
- Đăng nhập bằng tài khoản Parent (`parent1` / `Parent@123`).
- Tại **Bảng Điều Khiển Phụ Huynh**, cuộn tới mục **"Quản Lý Trẻ Em"**.
- Bấm **"Thêm / Liên kết"** -> Chọn **"Gán Tài Khoản Trẻ Vào Thiết Bị"**.
- Bấm thêm thiết bị mới:
  - Tên trẻ: `Bé Bắp`
  - Tên thiết bị: `Samsung Galaxy Tab A9`
  - Tài khoản của trẻ: Nhập `@be_bap`
- Bấm **"Lưu Thiết Bị"** -> Backend xác thực hợp lệ và lưu vào database.
- Bảng điều khiển phụ huynh lập tức hiển thị thẻ của **Bé Bắp** với huy hiệu xanh `Role: Child` và `@be_bap`.

### Bước 3: Trẻ Em Đăng Nhập & Truy Cập Dashboard
- Đăng xuất tài khoản Parent.
- Đăng nhập bằng tài khoản Child `be_bap`.
- Màn hình chuyển vào **Không Gian Của Trẻ Em (Child Dashboard)**:
  - Header hiển thị lời chào: *"Xin chào, Bé Bắp"*.
  - Hiển thị thiết bị được gán: `Samsung Galaxy Tab A9`.
  - Hiển thị đầy đủ 3 tính năng nâng cao: Face AI, Đo Tiếng Ồn, Quét QR.
  - Trẻ không thể chỉnh sửa thông số cấu hình hay xóa thiết bị của phụ huynh.

---
**KẾT LUẬN:** Task 04.3 đã hoàn thiện trọn vẹn chu trình quản lý tài khoản trẻ em trên nền tảng API backend thực tế, đảm bảo tính thẩm mỹ, bảo mật, responsive đa kích thước màn hình và đạt chuẩn chất lượng sản phẩm thương mại.
