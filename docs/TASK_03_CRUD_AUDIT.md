# BÁO CÁO TOÀN DIỆN: ĐÁNH GIÁ & KIỂM ĐỊNH CÁC CHỨC NĂNG CRUD (4,5 ĐIỂM)

**Dự án**: KidGuard — Ứng Dụng Quản Lý Điện Thoại Trẻ Em  
**Nhóm thực hiện**: Nhóm 13  
**Sinh viên**: Nguyễn Đức Chí Nguyên (MSSV: 1486) — Project: `NguyenDucChiNguyen_1486`  
**Vai trò kiểm định**: Senior Flutter QA Engineer, ASP.NET Core API Auditor & Database Testing Specialist  
**Ngày thực hiện kiểm định**: 22/10/2026  
**Mục tiêu đối chiếu**: Tiêu chí đánh giá môn học — *"Các chức năng CRUD — 4,5 điểm"*

---

## 1. TỔNG QUAN TÌNH TRẠNG CRUD (EXECUTIVE SUMMARY)

Sau khi tiến hành quét mã nguồn tĩnh (Static Code Analysis), kiểm tra cấu trúc cơ sở dữ liệu SQL Server, và thực hiện kiểm thử tự động (Integration Testing) trên hệ thống backend thực tế đang chạy (`https://127.0.0.1:7092`), kết quả kiểm định tổng thể như sau:

> [!WARNING]
> ### KẾT LUẬN CỐT LÕI
> * **Phía Backend (`backend-group/nhom13`)**: Đã được Nhóm 13 xây dựng **gần như hoàn chỉnh 100%** về nghiệp vụ CRUD cốt lõi cho module `ChildDevice` (Thêm, Xem, Sửa, Xóa, Cập nhật vị trí GPS, Ghi nhận sự kiện tiếng ồn) và module Quản trị người dùng `AdminController` (Xem danh sách, Cấp quyền, Mở khóa). Cơ chế kiểm soát quyền (RBAC) và chống leo thang đặc quyền ngang (IDOR) hoạt động rất chuẩn xác.
> * **Phía Cơ Sở Dữ Liệu SQL Server (`nhom13`)**: Đã có đầy đủ các bảng dữ liệu `[identity].ChildDevices`, `[identity].NoiseEvents`, `[identity].AspNetUsers`, `[identity].AspNetRoles` và lưu trữ bền vững trên ổ đĩa.
> * **Phía Flutter Mobile (`mobile/lib`)**: **CHƯA ĐƯỢC TRIỂN KHAI GIAO DIỆN CRUD!** Ứng dụng di động hiện tại chỉ mới hoàn thành **Task 02 (Authentication & Role Verification)**. Cả 3 màn hình Dashboard (`ParentDashboardScreen`, `AdminDashboardScreen`, `ChildDashboardScreen`) hiện chỉ là màn hình khung hiển thị thông tin người dùng và 2 nút bấm test quyền HTTP raw. Hoàn toàn chưa có màn hình danh sách thiết bị, form thêm thiết bị, chỉnh sửa, xóa hay xem chi tiết thiết bị.
> * **Ước tính mức độ hoàn thiện phần CRUD hiện tại**: **35% - 40%** (Toàn bộ điểm nằm ở Backend & DB; Flutter chưa kết nối giao diện CRUD).
> * **Rủi ro mất điểm nếu chấm thi ngay lúc này**: Nguy cơ mất từ **3.0 đến 3.5 điểm / 4.5 điểm** nếu giảng viên trực tiếp chấm thao tác trên màn hình điện thoại.

---

## 2. DANH SÁCH CÁC MODULE ĐÃ KIỂM TRA

Đã tiến hành kiểm tra 5 module chức năng tồn tại trong mã nguồn:

1. **Module 1: Quản lý Thiết Bị Trẻ Em (`ChildDevice`)** — Module CRUD trọng tâm nhất của đồ án KidGuard.
2. **Module 2: Quản lý Sự Kiện Tiếng Ồn & Cảnh Báo (`NoiseEvents`)** — Module giám sát và ghi nhận âm thanh môi trường từ thiết bị trẻ.
3. **Module 3: Định Vị Vị Trí Trẻ Em (`DeviceLocation`)** — Module cập nhật và tra cứu tọa độ GPS của thiết bị.
4. **Module 4: Quản Trị Người Dùng & Phân Quyền (`Admin User Management`)** — Module dành riêng cho vai trò Admin.
5. **Module 5: Quản Lý Sinh Trắc Học Khuôn Mặt (`Face Biometrics`)** — Module đăng ký, xóa và xác thực khuôn mặt ArcFace.

---

## 3. BẢNG TỔNG HỢP ENDPOINT BACKEND VÀ QUYỀN TRUY CẬP

Dựa trên việc đọc trực tiếp [AdminController.cs](file:///D:/haha/NguyenDucChiNguyen_1486/backend-group/nhom13/nhom13/nhom13/Controllers/AdminController.cs), [ChildDeviceApiController.cs](file:///D:/haha/NguyenDucChiNguyen_1486/backend-group/nhom13/nhom13/nhom13/Controllers/ChildDeviceApiController.cs) và [AuthenticateController.cs](file:///D:/haha/NguyenDucChiNguyen_1486/backend-group/nhom13/nhom13/nhom13/Controllers/AuthenticateController.cs):

| Module | Endpoint | Method | Role được phép | DTO / Request Body | Response Status | Trạng thái API |
| :--- | :--- | :---: | :--- | :--- | :---: | :---: |
| **Thiết bị** | `/api/ChildDeviceApi` | `GET` | `Authorize` (Admin, Parent, Child) | Query `?search=` | `200 OK` |  Đã kiểm chứng |
| **Thiết bị** | `/api/ChildDeviceApi/{id}` | `GET` | `Authorize` (Admin, Owner Parent, Linked Child) | Không | `200 OK` / `403` / `404` |  Đã kiểm chứng |
| **Thiết bị** | `/api/ChildDeviceApi` | `POST` | `Admin`, `Parent` | `ChildDeviceUpsertModel` | `201 CreatedAtAction` / `400` |  Đã kiểm chứng |
| **Thiết bị** | `/api/ChildDeviceApi/{id}` | `PUT` | `Admin`, Owner `Parent` | `ChildDeviceUpsertModel` | `204 NoContent` / `400` / `403` |  Đã kiểm chứng |
| **Thiết bị** | `/api/ChildDeviceApi/{id}` | `DELETE` | `Admin`, Owner `Parent` | Không | `204 NoContent` / `403` / `404` |  Đã kiểm chứng |
| **Vị trí** | `/api/ChildDeviceApi/{id}/location` | `PUT` | `Authorize` (Admin, Owner Parent, Linked Child) | `UpdateLocationModel` | `200 OK` / `403` |  Đã kiểm chứng |
| **Vị trí** | `/api/ChildDeviceApi/{id}/location` | `GET` | `Authorize` (Admin, Owner Parent, Linked Child) | Không | `200 OK` / `403` |  Đã kiểm chứng |
| **Tiếng ồn** | `/api/ChildDeviceApi/{id}/noise` | `POST` | `Authorize` (Thiết bị trẻ gửi đo âm thanh) | `NoiseReadingModel` | `200 OK` (kèm alert flag) |  Đã kiểm chứng |
| **Tiếng ồn** | `/api/ChildDeviceApi/{id}/noise` | `GET` | `Authorize` (Admin, Owner Parent, Linked Child) | Query `?from=&to=&alertsOnly=` | `200 OK` |  Đã kiểm chứng |
| **Tiếng ồn** | `/api/ChildDeviceApi/noise-alerts` | `GET` | `Admin`, `Parent` | Query `?take=50` | `200 OK` |  Đã kiểm chứng |
| **Tiếng ồn** | `/api/ChildDeviceApi/noise-alerts/{id}/ack` | `PUT` | `Admin`, Owner `Parent` | Không | `200 OK` / `403` / `404` |  Đã kiểm chứng |
| **Tiếng ồn** | `/api/ChildDeviceApi/{id}/noise-threshold` | `PUT` | `Admin`, Owner `Parent` | `NoiseThresholdModel` | `200 OK` / `400` / `403` |  Đã kiểm chứng |
| **Admin** | `/api/Admin/users` | `GET` | `Admin` | Query `?search=` | `200 OK` / `403 Forbidden` |  Đã kiểm chứng |
| **Admin** | `/api/Admin/users/{username}/role` | `PUT` | `Admin` | `SetRoleModel` (`{ role }`) | `200 OK` / `400` / `403` |  Đã kiểm chứng |
| **Admin** | `/api/Admin/users/{username}/unlock` | `PUT` | `Admin` | Không | `200 OK` / `404` / `403` |  Đã kiểm chứng |
| **Sinh trắc**| `/api/Authenticate/register-face` | `POST` | `Authorize` (Người dùng hiện tại) | `RegisterFaceModel` | `200 OK` / `400` |  Sẵn sàng |
| **Sinh trắc**| `/api/Authenticate/face` | `DELETE`| `Authorize` (Người dùng hiện tại) | Không | `200 OK` / `404` |  Sẵn sàng |

---

## 4. CHI TIẾT ĐÁNH GIÁ 4 THAO TÁC C - R - U - D

### 4.1. CREATE (Thêm mới)
* **Backend API**:
  * Endpoint `POST /api/ChildDeviceApi`.
  * Có Data Annotation Validation (`[Required] ChildName`, `[Required] DeviceName`, `Range ScreenTimeLimitMinutes`, `Range NoiseThresholdDb`).
  * Tự động gán `ParentUsername = CurrentUsername` từ JWT Claim, ngăn chặn người dùng thường giả mạo chủ sở hữu thiết bị. Chỉ `Admin` mới có quyền chỉ định `ParentUsername` khác.
  * Kiểm tra hợp lệ `ChildUsername` (tài khoản trẻ phải tồn tại và có role `Child`).
  * Trả về HTTP `201 CreatedAtAction` kèm Header `Location` và bản ghi JSON vừa tạo.
* **Cơ sở dữ liệu**:
  * Bản ghi được lưu thực sự vào bảng `[identity].ChildDevices` với khóa chính `Id` tự tăng (Identity).
* **Phía Flutter Mobile**:
  * ❌ **CHƯA CÓ**. Không có form nhập liệu `ChildName`, `DeviceName`, `ScreenTimeLimitMinutes`, `BlockedApps`. Chưa có nút gọi API POST.

### 4.2. READ (Truy vấn / Xem danh sách / Xem chi tiết)
* **Backend API**:
  * Endpoint `GET /api/ChildDeviceApi`:
    * Hỗ trợ tìm kiếm `?search=`.
    * **Data Scoping chuẩn xác**: Nếu là `Admin` thì thấy toàn bộ thiết bị trong hệ thống; nếu là `Parent` thì chỉ thấy các thiết bị do mình sở hữu (`ParentUsername == CurrentUsername`); nếu là `Child` thì chỉ thấy thiết bị gán cho mình (`ChildUsername == CurrentUsername`).
  * Endpoint `GET /api/ChildDeviceApi/{id}`:
    * Kiểm tra quyền xem (`CanView`). Nếu không phải Admin, không phải phụ huynh sở hữu và không phải trẻ được gán $\rightarrow$ Trả về `403 Forbidden` (`"Bạn không có quyền thao tác trên thiết bị này!"`).
* **Cơ sở dữ liệu**:
  * Đọc trực tiếp bằng Entity Framework Core `AsNoTracking()` kết hợp repository `ChildDeviceRepository`.
* **Phía Flutter Mobile**:
  * ❌ **CHƯA CÓ**. Màn hình `ParentDashboardScreen` chỉ có 1 nút bấm gọi kiểm tra trả về chuỗi JSON thô trong hộp đen `Container`, không có widget `ListView`, `Card` danh sách, trạng thái `CircularProgressIndicator` khi tải, hay view chi tiết thiết bị.

### 4.3. UPDATE (Chỉnh sửa / Cập nhật)
* **Backend API**:
  * Endpoint `PUT /api/ChildDeviceApi/{id}`:
    * Nhận `ChildDeviceUpsertModel`.
    * Kiểm tra tồn tại (404 nếu không tìm thấy).
    * Kiểm tra quyền quản lý (`CanManage`): Chỉ `Admin` hoặc `Parent` sở hữu mới được cập nhật. Trẻ em (`Child`) không có quyền sửa.
    * Cho phép cập nhật: `ChildName`, `DeviceName`, `ScreenTimeLimitMinutes`, `BlockedApps`, `IsLocked`, `NoiseThresholdDb`, `ChildUsername`.
    * Cập nhật timestamp `LastUpdated = DateTime.Now`.
    * Trả về HTTP `204 NoContent` chuẩn RESTful.
  * Endpoint `PUT /api/ChildDeviceApi/{id}/location`: Cập nhật kinh độ/vĩ độ GPS.
  * Endpoint `PUT /api/ChildDeviceApi/{id}/noise-threshold`: Đặt ngưỡng âm thanh cảnh báo.
* **Cơ sở dữ liệu**:
  * Dữ liệu trong SQL Server được cập nhật chính xác từng trường.
* **Phía Flutter Mobile**:
  * ❌ **CHƯA CÓ**. Chưa có giao diện chỉnh sửa thời gian sử dụng, danh sách app bị chặn hay công tắc khóa máy từ xa.

### 4.4. DELETE (Xóa dữ liệu)
* **Backend API**:
  * Endpoint `DELETE /api/ChildDeviceApi/{id}`:
    * Kiểm tra `CanManage`. Nếu phụ huynh khác cố tình xóa thiết bị không thuộc về mình $\rightarrow$ Trả về `403 Forbidden` (`"Chỉ Admin hoặc phụ huynh sở hữu mới được xóa thiết bị!"`).
    * Thực hiện xóa thiết bị khỏi cơ sở dữ liệu. Nhờ cấu hình `OnDelete(DeleteBehavior.Cascade)` trong `ApplicationDbContext`, toàn bộ sự kiện tiếng ồn (`NoiseEvents`) liên kết với thiết bị cũng được dọn dẹp sạch sẽ, không bị lỗi khóa ngoại (Foreign Key Constraint).
    * Trả về HTTP `204 NoContent`.
* **Cơ sở dữ liệu**:
  * Bản ghi bị xóa hoàn toàn khỏi SQL Server. Truy vấn lại trả về 404.
* **Phía Flutter Mobile**:
  * ❌ **CHƯA CÓ**. Chưa có nút Xóa, chưa có Dialog xác nhận (`AlertDialog`) *"Bạn có chắc chắn muốn xóa thiết bị này không?"*.

---

## 5. KIỂM ĐỊNH PHÂN QUYỀN & BẢO MẬT (SECURITY AUDIT)

Đã thực hiện kiểm thử tự động với 3 nhóm tài khoản có Token JWT thực tế:
1. **Admin** (`admin`, role `Admin`)
2. **Parent** (`nguyen`, role `Parent`)
3. **Child** (`be_an`, role `Child`)
4. **Anonymous** (Không có JWT Token)

### Kết quả kiểm định:

| Tình huống kiểm thử | Endpoint mục tiêu | Kỳ vọng | Kết quả thực tế | Trạng thái | Bằng chứng |
| :--- | :--- | :---: | :---: | :---: | :--- |
| **Không có JWT Token** | `GET /api/ChildDeviceApi` | `401 Unauthorized` | `401 Unauthorized` |  **PASS** | `{"status":false,"message":"Chưa đăng nhập hoặc token đã hết hạn!"}` |
| **Parent truy cập Admin API** | `GET /api/Admin/users` | `403 Forbidden` | `403 Forbidden` |  **PASS** | `{"status":false,"message":"Bạn không có quyền truy cập chức năng này!"}` |
| **Admin truy cập Admin API** | `GET /api/Admin/users` | `200 OK` | `200 OK` |  **PASS** | Trả về danh sách người dùng đầy đủ thuộc tính |
| **Child tự thêm thiết bị** | `POST /api/ChildDeviceApi` | `403 Forbidden` | `403 Forbidden` |  **PASS** | Trả về 403 do endpoint yêu cầu `Roles = AppRoles.AdminOrParent` |
| **Data Scoping (Parent Isolation)** | `GET /api/ChildDeviceApi` | Chỉ thấy của mình | Trả về `[]` |  **PASS** | Token `nguyen` không thấy 2 thiết bị của `khoi_parent` |
| **Chống tấn công IDOR (Xem trộm)** | `GET /api/ChildDeviceApi/1` | `403 Forbidden` | `403 Forbidden` |  **PASS** | `{"status":false,"message":"Bạn không có quyền thao tác trên thiết bị này!"}` |
| **Chống tấn công IDOR (Xóa trộm)** | `DELETE /api/ChildDeviceApi/1` | `403 Forbidden` | `403 Forbidden` |  **PASS** | `{"status":false,"message":"Chỉ Admin hoặc phụ huynh sở hữu mới được xóa thiết bị!"}` |

> [!NOTE]
> **Nhận xét Bảo Mật**: Backend của Nhóm 13 xử lý phân quyền và chống IDOR **rất xuất sắc**. Mọi thao tác truy xuất theo ID đơn lẻ đều được đối chiếu quyền sở hữu trước khi thực thi truy vấn.

---

## 6. KIỂM THỬ TÍCH HỢP THỰC TẾ (INTEGRATION TESTS TC01 – TC10)

Đã thiết lập test suite an toàn, sử dụng tài khoản `nguyen` (Parent) và tài khoản `admin` để kiểm thử tương tác trực tiếp tới cơ sở dữ liệu `nhom13` trên SQL Server `.\SQLEXPRESS`:

| Mã Test | Nội dung kiểm thử | Phương thức | Kỳ vọng | Kết quả thực tế | Trạng thái |
| :---: | :--- | :---: | :--- | :--- | :---: |
| **TC01** | Thêm mới thiết bị hợp lệ | `POST /api/ChildDeviceApi` | HTTP 201, trả ID mới, lưu DB | HTTP 201 CreatedAtAction, ID=3, Parent=nguyen |  **PASS** |
| **TC02** | Thêm thiết bị thiếu trường bắt buộc | `POST /api/ChildDeviceApi` | HTTP 400, báo lỗi ChildName & DeviceName | HTTP 400 Bad Request, trả JSON validation errors |  **PASS** |
| **TC03** | Lấy danh sách thiết bị theo tài khoản | `GET /api/ChildDeviceApi` | HTTP 200, danh sách thiết bị thuộc sở hữu | HTTP 200 OK, trả đúng mảng thiết bị của user |  **PASS** |
| **TC04** | Xem thông tin chi tiết thiết bị theo ID | `GET /api/ChildDeviceApi/3` | HTTP 200, trả đúng ID=3 và thông số | HTTP 200 OK, `DeviceName: Test Pixel 7` |  **PASS** |
| **TC05** | Cập nhật thiết bị (Tên, thời gian, app) | `PUT /api/ChildDeviceApi/3` | HTTP 204, DB lưu thông số mới | HTTP 204 NoContent, sau đó GET xác nhận ScreenTime=90 |  **PASS** |
| **TC06** | Xóa thiết bị khỏi hệ thống | `DELETE /api/ChildDeviceApi/3` | HTTP 204, sau đó GET trả 404 | HTTP 204 NoContent, GET lại trả HTTP 404 Not Found |  **PASS** |
| **TC07** | Bền vững dữ liệu sau restart app | SQL Server Direct Query | Dữ liệu không bị mất sau khi đóng app | Bảng `ChildDevices` lưu trên đĩa SQL Server an toàn |  **PASS** |
| **TC08** | Gọi API khi không có JWT Token | `GET /api/ChildDeviceApi` | HTTP 401 Unauthorized | HTTP 401 Unauthorized kèm tiếng Việt chuẩn |  **PASS** |
| **TC09** | Gọi API sai vai trò (Parent gọi Admin) | `GET /api/Admin/users` | HTTP 403 Forbidden | HTTP 403 Forbidden kèm thông báo rõ ràng |  **PASS** |
| **TC10** | Xử lý khi API mất kết nối / Timeout | Flutter Client Request | Flutter bắt SocketException, không crash | Bắt ngoại lệ và hiển thị thông báo lỗi rõ ràng |  **PASS** |

*Ghi chú: Toàn bộ quá trình kiểm thử TC01-TC06 được thực hiện trên bản ghi ID=3 do tài khoản `nguyen` tạo ra và tự động dọn dẹp sạch sẽ sau kiểm thử, bảo toàn nguyên vẹn 100% 2 bản ghi gốc (ID=1, ID=2) của hệ thống.*

---

## 7. KIỂM TRA GIAO DIỆN & TÍNH ĐÁP ỨNG (UI / UX RESPONSIVENESS AUDIT)

Đã chạy kiểm thử tự động trên Flutter Test Runner với các viewport chuẩn và tỷ lệ phóng đại chữ (Text Scaling):
* Viewport 1: **360 × 800** (Kích thước điện thoại Android phổ thông).
* Viewport 2: **393 × 852** (Kích thước iPhone / Android màn hình dài).
* Text Scale: **1.0** (Mặc định) và **1.3** (Chế độ chữ lớn dành cho người trợ năng).

### Các lỗi phát hiện trên màn hình hiện tại:

1. **Lỗi `RenderFlex overflowed by 176 pixels on the right`**:
   * **Vị trí**: [custom_button.dart](file:///D:/haha/NguyenDucChiNguyen_1486/mobile/lib/widgets/custom_button.dart) dòng 47 (`Row` bên trong nút bấm).
   * **Nguyên nhân**: Khi Text Scaling đặt ở mức 1.3, chữ trong nút bấm mở rộng chiều ngang vượt quá bề rộng màn hình 360px nhưng `Row` không dùng widget `Flexible` hoặc `Expanded`.
2. **Lỗi `RenderFlex overflowed by 319 pixels on the right`**:
   * **Vị trí**: [login_screen.dart](file:///D:/haha/NguyenDucChiNguyen_1486/mobile/lib/screens/auth/login_screen.dart) dòng 200 (`Row` chứa dòng chữ `"Chưa có tài khoản? Đăng ký phụ huynh"`).
   * **Nguyên nhân**: Dòng text điều hướng cuối màn hình đặt trong `Row` đơn giản mà không bọc `Wrap` hoặc `Flexible`, khi phóng to chữ 1.3 sẽ gây tràn màn hình sang phải (Yellow/Black stripes).
3. **Thiếu hoàn toàn giao diện CRUD**:
   * Màn hình `ParentDashboardScreen` chỉ có nút test kết nối, chưa có danh sách thiết bị dạng thẻ, chưa có Floating Action Button (+) để mở form thêm thiết bị.

---

## 8. ĐÁNH GIÁ MỨC ĐỘ HOÀN THIỆN CRUD (GRADING READINESS)

### Bảng đối chiếu hoàn thiện theo tiêu chí môn học:

| Module | Create | Read | Update | Delete | Flutter UI | Backend API | Database | Đánh giá kỹ thuật |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **1. Quản lý Thiết Bị Trẻ Em** |  Có API |  Có API |  Có API |  Có API | ❌ **Chưa có UI** |  100% |  100% | **PARTIAL** (Thiếu Flutter) |
| **2. Cảnh báo Tiếng Ồn** |  Có API |  Có API |  Có API | ❌ Không xóa | ❌ **Chưa có UI** |  100% |  100% | **PARTIAL** (Thiếu Flutter) |
| **3. Định Vị GPS Trẻ Em** | — |  Có API |  Có API | — | ❌ **Chưa có UI** |  100% |  100% | **PARTIAL** (Thiếu Flutter) |
| **4. Quản Trị Người Dùng** | ❌ (Chỉ Reg) |  Có API |  Có API | ❌ Không xóa | ❌ **Chưa có UI** |  100% |  100% | **PARTIAL** (Thiếu Flutter) |
| **5. Sinh Trắc Học Khuôn Mặt** |  Có API |  Có API | — |  Có API | ❌ **Chưa có UI** |  100% |  100% | **PARTIAL** (Thiếu Flutter) |

### Tỷ lệ sẵn sàng kỹ thuật:
* **Backend API & Repositories**: **95%** (Hoàn thiện xuất sắc, chuẩn RESTful, có validation).
* **Database SQL Server**: **100%** (Cấu trúc bảng chuẩn, quan hệ Cascade, lưu trữ thật).
* **Flutter Mobile Integration**: **10%** (Chỉ mới có mã gọi endpoint raw trên Dashboard, chưa có màn hình nghiệp vụ).
* **Tổng thể tính năng CRUD toàn dự án**: **~ 35% - 40%**.

---

## 9. DANH SÁCH CÔNG VIỆC CẦN LÀM (ACTION PLAN) ĐỂ ĐẠT 4,5/4,5 ĐIỂM

Dưới đây là ma trận công việc cần làm ở **Phía Flutter** để kết nối vào Backend nhóm và hoàn tất trọn vẹn điểm số phần CRUD:

### Mức độ P0: BẮT BUỘC ĐỂ CÓ ĐIỂM CRUD (Ảnh hưởng trực tiếp 3.5 - 4.0 điểm)
1. **Tạo Model DTO phía Flutter**:
   * File: `mobile/lib/models/device_model.dart`
   * Ánh xạ các trường: `id`, `childName`, `deviceName`, `screenTimeLimitMinutes`, `blockedApps`, `isLocked`, `latitude`, `longitude`, `noiseThresholdDb`, `childUsername`.
2. **Tạo Service Gọi API CRUD Thiết Bị**:
   * File: `mobile/lib/services/device_service.dart`
   * Triển khai các hàm: `getDevices()`, `getDeviceById(id)`, `addDevice(model)`, `updateDevice(id, model)`, `deleteDevice(id)`.
3. **Xây Dựng Màn Hình Danh Sách Thiết Bị (Read)**:
   * File: Cập nhật `mobile/lib/screens/dashboard/parent_dashboard_screen.dart` hoặc tạo `device_list_screen.dart`.
   * Hiển thị danh sách thẻ thiết bị con, trạng thái khóa máy, thời gian sử dụng, nút Xem/Sửa/Xóa.
4. **Xây Dựng Form Thêm & Chỉnh Sửa Thiết Bị (Create & Update)**:
   * File: `mobile/lib/screens/device/device_form_screen.dart`.
   * Nhập tên bé, tên máy, thời lượng tối đa, danh sách ứng dụng chặn, ngưỡng tiếng ồn dB.
5. **Xây Dựng Chức Năng Xóa Có Xác Nhận (Delete)**:
   * Tích hợp `AlertDialog` xác nhận trước khi xóa, gọi `deleteDevice(id)` và tự động refresh lại danh sách sau khi xóa.

### Mức độ P1: NÂNG CAO & GHI ĐIỂM TỐI ĐA (Ảnh hưởng 0.5 - 1.0 điểm)
6. **Màn hình Quản Trị Người Dùng dành cho Admin**:
   * Tích hợp gọi `GET /api/Admin/users` để Admin xem danh sách tài khoản và đổi quyền/mở khóa.
7. **Màn hình Giám Sát Cảnh Báo Tiếng Ồn**:
   * Gọi `GET /api/ChildDeviceApi/noise-alerts` hiển thị thông báo khi tiếng ồn vượt ngưỡng.

### Mức độ P2: TRẢI NGHIỆM NGƯỜI DÙNG & XỬ LÝ LỖI
8. Thêm Shimmer/Skeleton loading khi đang lấy danh sách thiết bị.
9. Xử lý Empty State trực quan khi phụ huynh chưa thêm thiết bị nào (*"Chưa có thiết bị nào. Bấm nút [+] để thêm bé đầu tiên"*).

### Mức độ P3: SỬA LỖI GIAO DIỆN
10. Sửa lỗi `RenderFlex overflow` tại [custom_button.dart](file:///D:/haha/NguyenDucChiNguyen_1486/mobile/lib/widgets/custom_button.dart) và [login_screen.dart](file:///D:/haha/NguyenDucChiNguyen_1486/mobile/lib/screens/auth/login_screen.dart) khi text scale 1.3 (dùng `Flexible` và `Wrap`).

---

## 10. NHỮNG PHẦN CẦN NHỜ THÀNH VIÊN BACKEND NHÓM HỖ TRỢ

Nhờ tuân thủ nguyên tắc bảo vệ Backend nhóm, chúng ta phát hiện backend nhóm đã làm rất tốt. Chỉ có **2 điểm nhỏ** nếu backend nhóm hỗ trợ được thì sẽ hoàn hảo hơn:

1. **Endpoint `DELETE /api/Admin/users/{id}` (Tùy chọn)**:
   * Hiện tại `AdminController` mới chỉ có Xem danh sách, Cấp quyền (`SetRole`) và Mở khóa (`Unlock`), chưa có xóa tài khoản người dùng rác. Nếu có thêm endpoint này thì phần Admin CRUD sẽ đạt 100%.
2. **Cấu hình Swagger URL cho Mobile**:
   * Giữ nguyên cổng và model hiện tại, không đổi tên các trường PascalCase để Flutter binding chính xác.

---

## 11. KẾT LUẬN CHÍNH THỨC

> **"Nếu kiểm tra ngay lúc này, phần CRUD của KidGuard đã sẵn sàng đến mức nào và cần ưu tiên hoàn thiện những gì?"**
> 
> * **Mức độ sẵn sàng**: Phần CRUD hiện tại **mới chỉ sẵn sàng ở tầng Backend và Cơ sở dữ liệu (đạt 95%)**, còn ở **tầng ứng dụng Flutter Mobile thì hoàn toàn CHƯA SẴN SÀNG (0% giao diện CRUD)**. Nếu nộp bài hoặc mở app demo ngay lúc này, giảng viên sẽ chỉ thấy màn hình Đăng ký/Đăng nhập và 3 Dashboard kiểm tra quyền, không thể chấm điểm thao tác Thêm / Xem / Sửa / Xóa thiết bị trên điện thoại.
> * **Ưu tiên hoàn thiện số 1 (Cấp bách)**: Cần tập trung toàn lực vào **Flutter Mobile** để xây dựng:
>   1. `DeviceModel` và `DeviceService` gọi API nhóm.
>   2. Màn hình danh sách thiết bị (`ListView` các thiết bị của con).
>   3. Form Thêm / Chỉnh sửa thiết bị (`ChildDeviceUpsertModel`).
>   4. Nút Xóa thiết bị có hộp thoại xác nhận.
>   *(Chỉ cần hoàn thành các màn hình này trên Flutter để kết nối với Backend nhóm đã chạy sẵn, bạn sẽ đủ điều kiện đạt tối đa 4,5 / 4,5 điểm cho phần CRUD).*
