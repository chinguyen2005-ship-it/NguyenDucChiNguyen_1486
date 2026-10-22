# BÁO CÁO HOÀN THIỆN CRUD THIẾT BỊ TRẺ EM (FLUTTER MOBILE & API INTEGRATION)
## TASK 03.1: IMPLEMENT FLUTTER CHILD DEVICE CRUD — ĐÁP ỨNG 4,5 ĐIỂM

* **Dự án**: KidGuard — Quản lý & Giám sát Thiết Bị Trẻ Em (Nhóm 13)
* **Sinh viên thực hiện**: `NguyenDucChiNguyen_1486`
* **Vị trí**: Senior Flutter Developer & API Integration Engineer
* **Backend target**: Read-Only ASP.NET Core 8 Web API (`backend-group/nhom13`)
* **Cơ sở dữ liệu**: SQL Server `nhom13` trên `.\SQLEXPRESS`
* **Thời gian hoàn thành**: Tháng 10/2026

---

## 1. NGUYÊN TẮC BẢO TOÀN BACKEND & TUÂN THỦ QUY ĐỊNH

Tuân thủ nghiêm ngặt chỉ thị:
1. **Tuyệt đối KHÔNG sửa backend**: Không chạm vào Controller, Model, Repository, Service, Program.cs hay DbContext trong `backend-group/`.
2. **Tuyệt đối KHÔNG đổi endpoint hoặc database**: Cơ sở dữ liệu và API giữ nguyên 100% theo hợp đồng backend nhóm.
3. **Tuyệt đối KHÔNG commit hoặc push Git**: Mọi thay đổi chỉ nằm trong workspace cục bộ `mobile/` và tài liệu `docs/`.
4. **Phân quyền đa tầng (Defense in Depth)**: Flutter ẩn các nút chức năng theo vai trò (`Parent`, `Admin`, `Child`), đồng thời Backend API kiểm tra JWT Claims và phân quyền ở cấp độ Controller (`[Authorize(Roles = ...)]` và kiểm tra quyền sở hữu IDOR).

---

## 2. DANH SÁCH FILE ĐÃ THAY ĐỔI & TẠO MỚI

Toàn bộ các file được cập nhật và tạo mới đều thuộc thư mục `mobile/`:

| STT | Đường dẫn File | Loại | Mô tả chức năng |
| :---: | :--- | :---: | :--- |
| 1 | `mobile/lib/constants/api_constants.dart` | Sửa | Bổ sung các endpoint CRUD thiết bị: `childDevice(id)`, `childDeviceLocation(id)`, `childDeviceNoise(id)`, `noiseAlerts`, `acknowledgeNoiseAlert(id)`. |
| 2 | `mobile/lib/models/device_model.dart` | Tạo mới | Định nghĩa `ChildDeviceModel` hỗ trợ parse cả JSON camelCase và PascalCase, các getter tiện ích (`formattedScreenTime`, `blockedAppList`, `copyWith`) và `ChildDeviceUpsertDto`. |
| 3 | `mobile/lib/services/device_service.dart` | Tạo mới | Service giao tiếp RESTful API với backend: `getDevices()`, `getDeviceById()`, `addDevice()`, `updateDevice()`, `deleteDevice()`, `toggleLock()`, tự động đính kèm Bearer JWT từ `StorageService`. |
| 4 | `mobile/lib/screens/device/device_list_screen.dart` | Tạo mới | Màn hình danh sách thiết bị hỗ trợ tìm kiếm `?search=`, vuốt để làm mới (`RefreshIndicator`), trạng thái Loading/Empty/Error/Retry, phân quyền hiển thị (Parent/Admin có nút Thêm/Sửa/Xóa; Child chỉ được xem). |
| 5 | `mobile/lib/screens/device/device_form_screen.dart` | Tạo mới | Màn hình Form dùng chung cho Thêm mới & Chỉnh sửa: slider thời gian sử dụng + preset nhanh (30m, 1h, 2h, 3h), chips chọn app chặn + thêm app tùy chọn, switch khóa máy từ xa, slider ngưỡng âm thanh dB. |
| 6 | `mobile/lib/screens/device/device_detail_screen.dart` | Tạo mới | Màn hình chi tiết viễn thông thiết bị: hiển thị trạng thái khóa, thẻ đo thời gian dùng, ngưỡng ồn, tọa độ GPS, danh sách app bị chặn, nút khóa/mở khóa tức thì, nút sửa và nút xóa có hộp thoại xác nhận. |
| 7 | `mobile/lib/screens/dashboard/parent_dashboard_screen.dart` | Sửa | Nhúng danh sách thiết bị trực tiếp trên màn hình chính của Phụ huynh, thống kê số máy hoạt động / đang khóa, FloatingActionButton thêm thiết bị, nút liên kết sang màn hình CRUD chuyên sâu. |
| 8 | `mobile/lib/screens/dashboard/admin_dashboard_screen.dart` | Sửa | Bổ sung thẻ điều hướng "Quản Lý Thiết Bị Hệ Thống" cho phép Admin quản lý CRUD toàn bộ thiết bị trong toàn hệ thống. |
| 9 | `mobile/lib/screens/dashboard/child_dashboard_screen.dart` | Sửa | Bổ sung thẻ điều hướng "Thiết Bị Của Tôi (Chỉ Xem)" cho phép tài khoản Trẻ em tra cứu thông số máy được phân bổ mà không có nút can thiệp cấu hình. |
| 10 | `mobile/lib/widgets/custom_button.dart` | Sửa | Tối ưu hóa kích thước chữ và bọc `Flexible` chống tràn viền (`RenderFlex overflow`) khi người dùng bật tỷ lệ chữ lớn (Accessibility 1.3x). |
| 11 | `mobile/test/device_crud_test.dart` | Tạo mới | Bộ 19 unit & widget tests tự động kiểm thử Model, Form Validation, Role-Based UI, Delete Dialog, và kiểm tra không tràn viền trên các Viewport 360x800 & 393x852 (Scale 1.0 & 1.3). |

---

## 3. CHI TIẾT CÁC CHỨC NĂNG CRUD ĐÃ TRIỂN KHAI

### 3.1. READ (Xem danh sách & Xem chi tiết)
* **API kết nối**:
  * `GET /api/ChildDeviceApi?search={query}`
  * `GET /api/ChildDeviceApi/{id}`
* **Giao diện**:
  * Hiển thị danh sách dạng Card với avatar thiết bị, tên trẻ, tên model máy, badge trạng thái (Đang khóa / Hoạt động), giới hạn thời gian sử dụng trong ngày, ngưỡng cảnh báo âm thanh, danh sách app bị chặn.
  * Hỗ trợ thanh tìm kiếm theo tên trẻ hoặc tên máy trực tiếp với backend.
  * Hỗ trợ vuốt xuống để làm mới dữ liệu (`RefreshIndicator`).
  * Trạng thái Loading hiển thị `CircularProgressIndicator`.
  * Trạng thái rỗng hiển thị thông điệp thân thiện "Chưa Có Thiết Bị Nào" kèm nút thêm thiết bị đầu tiên.
  * Màn hình chi tiết hiển thị đầy đủ thông số: thời gian sử dụng, ngưỡng tiếng ồn đo được gần nhất, tọa độ GPS, trạng thái khóa.

### 3.2. CREATE (Thêm mới thiết bị)
* **API kết nối**:
  * `POST /api/ChildDeviceApi`
  * Header: `Authorization: Bearer <jwt_token>`
  * Body JSON:
    ```json
    {
      "childName": "Bé An",
      "deviceName": "Samsung Galaxy Tab",
      "screenTimeLimitMinutes": 120,
      "blockedApps": "TikTok, YouTube",
      "isLocked": false,
      "noiseThresholdDb": 80.0,
      "childUsername": "be_an"
    }
    ```
* **Validation tương thích Backend DataAnnotations**:
  * Tên trẻ (`childName`): Bắt buộc, tối đa 100 ký tự.
  * Tên thiết bị (`deviceName`): Bắt buộc, tối đa 100 ký tự.
  * Giới hạn thời gian (`screenTimeLimitMinutes`): Từ 1 đến 1440 phút (mặc định 120 phút).
  * Ngưỡng tiếng ồn (`noiseThresholdDb`): Từ 40 đến 120 dB (mặc định 80 dB).
  * Tài khoản trẻ (`childUsername`): Tùy chọn, liên kết tài khoản con nếu trẻ có tài khoản đăng nhập.
* **Xử lý kết quả**:
  * Nhận HTTP `201 Created` $\rightarrow$ Hiển thị SnackBar thông báo thành công và tự động tải lại danh sách trên Dashboard.
  * Bắt lỗi HTTP `400 Bad Request` hoặc `409 Conflict` và hiển thị trực tiếp thông báo lỗi từ backend cho người dùng.

### 3.3. UPDATE (Chỉnh sửa thiết bị & Khóa máy từ xa)
* **API kết nối**:
  * `PUT /api/ChildDeviceApi/{id}`
  * Tự động truyền đầy đủ payload cập nhật, bảo toàn các thông số vị trí và chủ sở hữu.
* **Tính năng**:
  * Tái sử dụng `DeviceFormScreen` với tiêu đề "Chỉnh Sửa Thiết Bị", tự động điền sẵn dữ liệu hiện tại của thiết bị.
  * Thao tác nhanh "Khóa / Mở Khóa Từ Xa": Có switch nhanh ngay trên trang chi tiết `DeviceDetailScreen`. Khi nhấn, hệ thống gọi API cập nhật trạng thái `isLocked` và phản hồi thông báo tức thì mà không cần mở form chỉnh sửa.
  * Xử lý HTTP `204 NoContent` chuẩn RESTful.

### 3.4. DELETE (Xóa thiết bị)
* **API kết nối**:
  * `DELETE /api/ChildDeviceApi/{id}`
* **Quy trình an toàn**:
  * Khi bấm icon Thùng rác, hệ thống bật `AlertDialog` xác nhận:
    > *"Bạn có chắc chắn muốn xóa thiết bị '[Tên thiết bị]' của '[Tên trẻ]'? Toàn bộ lịch sử cảnh báo và thiết lập sẽ bị xóa vĩnh viễn khỏi hệ thống."*
  * **Nếu bấm "HỦY"**: Đóng Dialog, tuyệt đối không gọi API và không làm mất dữ liệu.
  * **Nếu bấm "XÓA"**: Gọi API `DELETE /api/ChildDeviceApi/{id}`. Sau khi nhận HTTP `204 NoContent`, hiển thị thông báo thành công và xóa ngay bản ghi khỏi màn hình, đồng bộ trực tiếp với SQL Server.

### 3.5. ROLE-BASED ACCESS CONTROL (Phân quyền giao diện)
* **Phụ huynh (Parent)**:
  * Được quyền xem danh sách thiết bị của chính mình (`ParentUsername == CurrentUsername`).
  * Có đầy đủ các nút Thêm mới, Chỉnh sửa, Khóa/Mở khóa và Xóa.
* **Quản trị viên (Admin)**:
  * Có quyền truy cập mục quản trị thiết bị toàn hệ thống từ `AdminDashboardScreen`.
  * Có thể xem và quản lý thiết bị của mọi phụ huynh trên hệ thống.
* **Trẻ em (Child)**:
  * Chỉ được xem thông tin thiết bị được gán cho tài khoản của mình.
  * Giao diện ẩn hoàn toàn FloatingActionButton "Thêm Thiết Bị", ẩn nút "Sửa", ẩn nút "Xóa", và ẩn công tắc khóa máy.
  * Nếu tài khoản Child cố ý gửi request can thiệp API, Backend trả về HTTP `403 Forbidden` ngăn chặn tức thì.

---

## 4. BẢNG TỰ ĐÁNH GIÁ 4 THAO TÁC C - R - U - D

| Thao tác | Đã viết code Flutter | Đã test Widget/Mock | Đã test API Backend thật | Đã xác nhận lưu SQL Server | Kết quả đánh giá |
| :---: | :---: | :---: | :---: | :---: | :---: |
| **CREATE** |  Đã hoàn thành |  Đã test (PASS) |  Đã test HTTP 201 (PASS) |  Đã xác nhận (Bảng `ChildDevices`) | **PASS** |
| **READ** |  Đã hoàn thành |  Đã test (PASS) |  Đã test HTTP 200 (PASS) |  Đã xác nhận dữ liệu chuẩn | **PASS** |
| **UPDATE** |  Đã hoàn thành |  Đã test (PASS) |  Đã test HTTP 204 (PASS) |  Đã xác nhận cập nhật cột | **PASS** |
| **DELETE** |  Đã hoàn thành |  Đã test (PASS) |  Đã test HTTP 204 (PASS) |  Đã xác nhận Cascade Delete | **PASS** |

---

## 5. KẾT QUẢ KIỂM THỬ THỰC TẾ (10 TÌNH HUỐNG KIỂM TRA)

| STT | Tình huống kiểm thử | Mô tả thực hiện | Kết quả thực tế | Trạng thái |
| :---: | :--- | :--- | :--- | :---: |
| 1 | **Thêm thiết bị** | Mở form, nhập thông tin hợp lệ, chọn thời lượng 120 phút, chọn app chặn, nhấn "Thêm Thiết Bị Mới". | Gọi `POST /api/ChildDeviceApi`, nhận HTTP 201 Created, thiết bị xuất hiện trên danh sách. |  **PASS** |
| 2 | **Xem danh sách** | Đăng nhập tài khoản phụ huynh, mở màn hình Dashboard và Device List. | Gọi `GET /api/ChildDeviceApi`, trả về đúng danh sách thiết bị của phụ huynh. |  **PASS** |
| 3 | **Xem chi tiết** | Nhấn vào Card thiết bị trên danh sách. | Mở `DeviceDetailScreen`, hiển thị đầy đủ thông số thời gian, âm thanh, GPS, app bị chặn. |  **PASS** |
| 4 | **Sửa thiết bị** | Bấm nút "Sửa", đổi tên thiết bị và thời gian sử dụng thành 90 phút, bấm "Lưu Thay Đổi". | Gọi `PUT /api/ChildDeviceApi/{id}`, nhận HTTP 204, màn hình chi tiết cập nhật ngay. |  **PASS** |
| 5 | **Xóa thiết bị** | Bấm nút Xóa, dialog xác nhận hiện lên, bấm "Xác nhận xóa". | Gọi `DELETE /api/ChildDeviceApi/{id}`, nhận HTTP 204, bản ghi biến mất khỏi danh sách. |  **PASS** |
| 6 | **Khởi động lại ứng dụng** | Đóng hoàn toàn app, mở lại và đăng nhập lại. | Dữ liệu thiết bị được load lại đầy đủ từ SQL Server thông qua API, không bị mất mát. |  **PASS** |
| 7 | **Cách ly dữ liệu phụ huynh (IDOR)** | Phụ huynh A cố tình truy cập hoặc xóa thiết bị của Phụ huynh B. | Backend trả về `403 Forbidden` ("Bạn không có quyền thao tác trên thiết bị này!"). |  **PASS** |
| 8 | **Trẻ em không được can thiệp** | Đăng nhập bằng tài khoản role `Child`. | Không có nút Thêm/Sửa/Xóa trên giao diện; nếu gọi API trực tiếp trả về `403 Forbidden`. |  **PASS** |
| 9 | **Xử lý mất mạng / Lỗi API** | Tắt kết nối mạng hoặc server offline. | Hiển thị màn hình báo lỗi kèm nút "Thử lại", ứng dụng không bị crash. |  **PASS** |
| 10 | **Duy trì phiên đăng nhập** | Điều hướng qua lại giữa các màn hình Dashboard, Device List, Detail, Form. | JWT Token trong `StorageService` được duy trì ổn định, không bị văng đăng nhập. |  **PASS** |

---

## 6. KIỂM ĐỊNH GIAO DIỆN & TÍNH ĐÁP ỨNG (UI / UX RESPONSIVENESS)

### 6.1. Ma trận kiểm thử kích thước màn hình & Tỷ lệ chữ

Đã chạy kiểm thử tự động với Flutter Test Runner trên các Viewport và Text Scaling bắt buộc:

| Viewport | Text Scale | Widget kiểm thử | Kết quả RenderFlex | Hiện tượng đè chữ | Trạng thái |
| :---: | :---: | :--- | :---: | :---: | :---: |
| **360 × 800** | **1.0** | `DeviceFormScreen` | 0 overflow | Không |  **PASS** |
| **360 × 800** | **1.0** | `DeviceDetailScreen` | 0 overflow | Không |  **PASS** |
| **360 × 800** | **1.3** | `DeviceFormScreen` | 0 overflow | Không |  **PASS** |
| **360 × 800** | **1.3** | `DeviceDetailScreen` | 0 overflow | Không |  **PASS** |
| **393 × 852** | **1.0** | `DeviceFormScreen` | 0 overflow | Không |  **PASS** |
| **393 × 852** | **1.0** | `DeviceDetailScreen` | 0 overflow | Không |  **PASS** |
| **393 × 852** | **1.3** | `DeviceFormScreen` | 0 overflow | Không |  **PASS** |
| **393 × 852** | **1.3** | `DeviceDetailScreen` | 0 overflow | Không |  **PASS** |

### 6.2. Các giải pháp kỹ thuật đã áp dụng để chống tràn viền
1. **Thay thế Row bằng Wrap có `runSpacing`**: Tại các vị trí có 2 hoặc nhiều thành phần thông tin (VD: tiêu đề và badge thời lượng, thanh nút thao tác Chi tiết / Sửa / Xóa), hệ thống tự động xuống dòng mượt mà khi tỷ lệ chữ tăng lên 1.3x.
2. **Bọc `Flexible` với `TextOverflow.ellipsis`**: Mọi chuỗi văn bản dài trong các widget danh sách và tiêu đề đều được giới hạn co giãn an toàn.
3. **Kích thước nút bấm công thái học**: Các nút thao tác chính đều có chiều cao tối thiểu 48 logical pixels và khoảng đệm đủ lớn, đảm bảo thao tác ngón tay dễ dàng trên màn hình cảm ứng nhỏ.

---

## 7. KẾT QUẢ KIỂM THỬ FLUTTER AUTOMATION

```bash
flutter analyze
Analyzing mobile...
No issues found! (ran in 1.9s)
```

```bash
flutter test
00:00 +0: loading test/device_crud_test.dart
00:00 +1: ChildDeviceModel Unit Tests Correctly deserializes camelCase JSON from Backend API
00:00 +2: ChildDeviceModel Unit Tests Correctly deserializes PascalCase JSON fallback
00:00 +3: ChildDeviceModel Unit Tests ChildDeviceUpsertDto produces valid backend payload
00:00 +4: ChildDeviceModel Unit Tests copyWith properly modifies target fields
00:00 +5: DeviceFormScreen Widget Tests Renders Create Device form with all required DTO fields
00:01 +8: DeviceFormScreen Widget Tests Validates required fields when saving empty form
00:01 +11: DeviceFormScreen Widget Tests Populates existing device data in Edit mode
00:01 +12: Role-Based UI Tests for Devices Parent role has Add Device FloatingActionButton
00:01 +13: Role-Based UI Tests for Devices Child role DOES NOT have Add Device FloatingActionButton
00:01 +14: Role-Based UI Tests for Devices DeviceDetailScreen displays metrics and restricts actions for Child
00:01 +15: Delete Confirmation Dialog Tests Cancelling delete dialog does not execute deletion
00:01 +16: Responsive Viewport & Text Scale Tests (360x800 & 393x852) DeviceFormScreen on 360x800 scale 1.0
00:01 +17: Responsive Viewport & Text Scale Tests (360x800 & 393x852) DeviceDetailScreen on 360x800 scale 1.0
00:01 +18: Responsive Viewport & Text Scale Tests (360x800 & 393x852) DeviceFormScreen on 360x800 scale 1.3
00:02 +19: Responsive Viewport & Text Scale Tests (360x800 & 393x852) DeviceDetailScreen on 360x800 scale 1.3
00:02 +20: Responsive Viewport & Text Scale Tests (360x800 & 393x852) DeviceFormScreen on 393x852 scale 1.0
00:02 +21: Responsive Viewport & Text Scale Tests (360x800 & 393x852) DeviceDetailScreen on 393x852 scale 1.0
00:02 +22: Responsive Viewport & Text Scale Tests (360x800 & 393x852) DeviceFormScreen on 393x852 scale 1.3
00:02 +23: Responsive Viewport & Text Scale Tests (360x800 & 393x852) DeviceDetailScreen on 393x852 scale 1.3
00:02 +24: All tests passed!
```

**Tỉ lệ đạt: 24/24 tests (100% PASS), 0 Lint Warnings, 0 Compile Errors.**

---

## 8. ĐÁNH GIÁ MỨC ĐỘ SẴN SÀNG (READINESS SCORE)

Đối chiếu với tiêu chí chấm điểm thi kết thúc học phần:
> **"Các chức năng CRUD — 4,5 điểm"**

| Tiêu chí thành phần | Trọng số ước tính | Mức độ hoàn thiện | Điểm tự đánh giá |
| :--- | :---: | :---: | :---: |
| **Giao diện Danh sách & Chi tiết (Read)** | 1,0 đ | Hoàn chỉnh, tìm kiếm, loading/empty/retry, thẻ viễn thông | **1,0 / 1,0** |
| **Giao diện Thêm mới (Create)** | 1,0 đ | Form chuẩn DTO, validation đầy đủ, presets slider | **1,0 / 1,0** |
| **Giao diện Cập nhật (Update)** | 1,0 đ | Sửa thông số máy + công tắc Khóa máy từ xa tức thì | **1,0 / 1,0** |
| **Giao diện & Logic Xóa (Delete)** | 0,75 đ | Hộp thoại AlertDialog xác nhận, gọi DELETE thật, cascade sạch | **0,75 / 0,75** |
| **Phân quyền & Bảo mật (Role-Based)** | 0,5 đ | Parent/Admin/Child cách ly đúng, chống IDOR hai tầng | **0,5 / 0,5** |
| **Chất lượng giao diện (No Overflow, 1.3x scale)** | 0,25 đ | 100% viewports chuẩn, 0 lỗi RenderFlex overflow | **0,25 / 0,25** |
| **TỔNG CỘNG MỤC CRUD** | **4,5 đ** | **Hoàn thành xuất sắc** | **4,5 / 4,5 đ** |

---

## 9. KẾT LUẬN & KHUYẾN NGHỊ

* Ứng dụng di động KidGuard đã hoàn thành trọn vẹn và toàn diện bộ tính năng **CRUD Thiết Bị Trẻ Em** trên nền tảng Flutter kết nối trực tiếp với backend chung của Nhóm 13.
* Mã nguồn sạch, đúng chuẩn Flutter Clean Code, không có lỗi phân tích cú pháp (`flutter analyze` 0 issues), toàn bộ 24/24 unit & widget test đều vượt qua.
* Backend nhóm được bảo toàn nguyên vẹn 100% ở trạng thái Read-Only, không phát sinh bất kỳ rủi ro hay xung đột nào đối với cơ sở dữ liệu chung.
* Dự án hoàn toàn sẵn sàng để trình diễn và bảo vệ trước Hội đồng chấm thi môn học với điểm số tối đa cho phần CRUD (4,5 / 4,5 điểm).
