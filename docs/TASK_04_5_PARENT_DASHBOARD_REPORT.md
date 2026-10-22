# BÁO CÁO KỸ THUẬT: THIẾT KẾ LẠI BẢNG ĐIỀU KHIỂN PHỤ HUYNH THEO VAI TRÒ (ROLE-BASED REDESIGN)
**Mã Nhiệm Vụ:** TASK 04.5  
**Dự Án:** KidGuard — Quản Lý Điện Thoại Trẻ Em (Nhóm 13)  
**Đường Dẫn Dự Án:** `D:\haha\NguyenDucChiNguyen_1486`  
**Ngày Thực Hiện:** 22/10/2026  
**Chuyên Viên:** Senior Flutter UI/UX Engineer  
**Trạng Thái:** **HOÀN TẤT 100% — ZERO LINT ISSUES — 80/80 TESTS PASSED (100%)**

---

## 1. TỔNG QUAN VÀ MỤC TIÊU CẢI TỔ

### 1.1. Bối Cảnh Và Vấn Đề Trước Khi Cải Tổ
Trước khi thực hiện Task 04.5, giao diện Bảng điều khiển Phụ huynh (`ParentDashboardScreen`) gặp một số bất cập về mặt trải nghiệm và bản chất vai trò ứng dụng:
1. **Khối nút ngang Task 04:** Tồn tại khối "Tính Năng Nâng Cao (Task 04)" gồm 3 nút ngang (*Face AI*, *Tiếng Ồn*, *Quét QR*) mang tính kỹ thuật phục vụ chấm bài, không phản ánh đúng cấu trúc nghiệp vụ của một ứng dụng quản lý giám sát trẻ em.
2. **Sai lệch bản chất tính năng đo tiếng ồn:** Giao diện phụ huynh trước đây cung cấp nút "Mở Máy Đo Độc Lập" hoặc kích hoạt cảm biến micro ngay trên điện thoại phụ huynh. Trên thực tế, **Phụ huynh cần giám sát tiếng ồn môi trường xung quanh điện thoại của con**, nhận cảnh báo vi phạm và quản trị ngưỡng an toàn, chứ **không phải bật micro đo tiếng ồn phòng của phụ huynh**.
3. **Trộn lẫn thông tin kỹ thuật:** Các nút kiểm thử token HTTP/JWT hiển thị lộ thiên giữa màn hình làm phân tán người dùng.
4. **Mã QR:** Dữ liệu tra cứu toàn vẹn đôi khi bị gọi là "chữ ký số" thay vì thuật toán kiểm tra toàn vẹn băm `checksum FNV-1a`.

### 1.2. Mục Tiêu Đạt Được
- **Tái thiết kế toàn diện Dashboard Phụ huynh:** Xóa bỏ khối nút ngang Task 04, chia lại thành **4 nhóm chức năng chuẩn mực**:
  - **Nhóm A — Tổng Quan Giám Sát:** Thống kê 2x2 trực quan (Số thiết bị, Trạng thái Khóa/Hoạt động, Hồ sơ trẻ em, Số lượng cảnh báo tiếng ồn thực tế từ Backend).
  - **Nhóm B — Quản Lý Trẻ Em:** Danh sách trẻ em được liên kết, thẻ hồ sơ trẻ kèm username `@child`, quy trình thêm và gán tài khoản trẻ.
  - **Nhóm C — Theo Dõi & Quản Lý:** 
    - *Thiết bị của con:* Quản lý vòng đời thiết bị (CRUD).
    - *Giám sát tiếng ồn:* Theo dõi số đo Telemetry, lịch sử vượt ngưỡng, xác nhận cảnh báo vi phạm, điều chỉnh ngưỡng qua API thật (`PUT .../noise-threshold`). Phụ huynh tuyệt đối **không** dùng micro cục bộ để đo.
    - *Quét mã QR:* Mở trình quét tra cứu thông tin thiết bị và kiểm tra mã toàn vẹn FNV-1a, cảnh báo rõ ràng backend chưa hỗ trợ tự động ghép nối (pair).
  - **Nhóm D — Bảo Mật Tài Khoản:** Quản lý sinh trắc học Face AI của tài khoản phụ huynh (đăng ký/cập nhật/xóa mẫu khuôn mặt cá nhân), minh bạch không truy cập hay can thiệp vào khuôn mặt của trẻ.
  - **Khu Vực Kỹ Thuật (Development & Grading):** Gom cụm các nút kiểm thử JWT vào khu vực riêng biệt ở chân trang.
- **Tuân thủ tuyệt đối quy tắc READ-ONLY Backend:** Toàn bộ thư mục `backend-group/nhom13` giữ nguyên 100%, không đổi database, không commit/push Git.
- **Giao diện chuẩn Material 3 & Responsive:** Đạt chuẩn hiển thị trên mọi độ phân giải (320px, 360px, 393px, 430px) và hỗ trợ trợ năng chữ lớn 1.3x không bị tràn viền (`RenderFlex overflow`).

---

## 2. MA TRẬN PHÂN QUYỀN VAI TRÒ (ROLE-BASED RBAC)

```
                            KIẾN TRÚC PHÂN ĐỊNH RANH GIỚI VAI TRÒ
 ┌────────────────────────────────────────────────────────────────────────────────────────┐
 │                                   PHỤ HUYNH (PARENT)                                   │
 │  • Giám sát trung tâm: Xem số thiết bị, trạng thái khóa, số trẻ em, số cảnh báo ồn.   │
 │  • Quản lý tài khoản trẻ: Tạo tài khoản Child (OTP Email), gán @username vào thiết bị.│
 │  • Quản lý thiết bị: Toàn quyền CRUD (Xem, Thêm, Sửa, Khóa/Mở, Xóa thiết bị).          │
 │  • Giám sát tiếng ồn:                                                                 │
 │    - Xem Telemetry số đo dB gửi từ máy con (Mean, Peak, Breach Count).                │
 │    - Cập nhật ngưỡng cảnh báo an toàn (PUT /api/ChildDeviceApi/{id}/noise-threshold).   │
 │    - Xác nhận đã xem cảnh báo (PUT /api/ChildDeviceApi/noise-alerts/{id}/ack).         │
 │    - 🚫 KHÔNG kích hoạt microphone trên máy phụ huynh.                                 │
 │    - 🚫 KHÔNG giả lập lệnh đo từ xa khi Backend thiếu kênh downstream (BLOCKED).       │
 │  • Quét QR: Quét mã QR máy con để tra cứu thiết bị và kiểm tra toàn vẹn FNV-1a.       │
 │  • Bảo mật cá nhân: Đăng ký/cập nhật/xóa Face AI của chính mình.                       │
 └────────────────────────────────────────────────────────────────────────────────────────┘
                                              ▲
                                              │ (Dữ liệu HTTP REST API thật)
                                              ▼
 ┌────────────────────────────────────────────────────────────────────────────────────────┐
 │                                     TRẺ EM (CHILD)                                     │
 │  • Xem thiết bị được gán và thời gian sử dụng còn lại.                                 │
 │  • Đo tiếng ồn môi trường:                                                             │
 │    - Tự thực hiện đo thủ công trên máy mình với sự minh bạch về quyền riêng tư.        │
 │    - Nút Bắt đầu / Dừng đo rõ ràng; dừng đo lập tức giải phóng Microphone stream.     │
 │    - 🚫 Slider ngưỡng bị KHÓA CHẶT (Chỉ đọc - Do phụ huynh thiết lập).                │
 │    - 🚫 Không gửi dữ liệu mô phỏng lên server thật khi không có cảm biến.             │
 │  • Mã QR: Hiển thị mã QR thiết bị định danh kèm mã kiểm tra toàn vẹn FNV-1a.           │
 │  • Bảo mật: Đăng ký/xóa Face AI riêng của tài khoản con để đăng nhập nhanh.           │
 │  • 🚫 KHÔNG CÓ quyền CRUD thiết bị, không có quyền đổi ngưỡng an toàn.                 │
 └────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. SO SÁNH GIAO DIỆN TRƯỚC VÀ SAU CẢI TỔ

| Thành Phần | Giao Diện Cũ | Giao Diện Mới (Redesigned) |
| :--- | :--- | :--- |
| **Thanh tính năng nâng cao** | Khối Card "Tính Năng Nâng Cao (Task 04)" chứa 3 nút bấm ngang (*Face AI*, *Tiếng Ồn*, *Quét QR*). | **Đã xóa bỏ hoàn toàn**. Thay thế bằng các nhóm chức năng tự nhiên: Nhóm C (Theo dõi & Quản lý) và Nhóm D (Bảo mật tài khoản). |
| **Tổng quan thống kê** | Dòng 3 chỉ số đơn điệu (*Thiết bị con*, *Đang khóa*, *Trẻ em*). | **Lưới 2x2 đàn hồi:** Thiết bị con (hiển thị số máy hoạt động/khóa), Đang khóa, Hồ sơ trẻ em đã liên kết, và **Cảnh báo tiếng ồn thật từ API backend** (bấm vào mở danh sách sự kiện vi phạm để xác nhận). |
| **Đo tiếng ồn (Parent)** | Có nút mở máy đo độc lập bằng micro máy phụ huynh; giao diện gây hiểu lầm phụ huynh tự đo tiếng ồn cho con. | **Chuyển thành Hub Telemetry:** Phụ huynh chỉ theo dõi báo cáo gửi từ máy con, cập nhật ngưỡng an toàn, xem và xác nhận cảnh báo. **Loại bỏ 100% nút đo micro trên máy phụ huynh**. |
| **Quét mã QR** | Nút mở quét QR nằm ngang trên thanh Task 04; kết quả quét từng hiển thị nút "Đo tiếng ồn thiết bị" cho cả phụ huynh. | **Tách thành thẻ Tra cứu QR riêng biệt:** Giải thích rõ mục đích tra cứu và kiểm tra toàn vẹn FNV-1a. Nút hành động sau quét phân biệt rõ vai trò: Phụ huynh xem bảng giám sát & ngưỡng, con mở máy đo. |
| **Bảo mật Face AI** | Nút Face AI nằm chung trên thanh 3 nút Task 04; thiếu giải thích về quyền riêng tư. | **Khu vực Bảo mật tài khoản chuyên biệt:** Quản lý Face AI của phụ huynh, trạng thái kích hoạt, nút đăng ký/cập nhật và nút xóa mẫu. Cam kết minh bạch không can thiệp Face AI của con. |
| **Khu vực Debug/Grading** | Nằm lẫn lộn giữa màn hình chính với các thuật ngữ HTTP trạng thái 200/403. | Đặt gọn gàng trong Card kỹ thuật ở chân trang: *"Kiểm Thử Phân Quyền Backend Thực Tế (JWT)"*. |
| **Độ co giãn Responsive** | Có nguy cơ tràn viền `RenderFlex` khi ở kích thước 320px và font scale 1.3x. | **100% Không tràn viền:** Mọi tiêu đề và hàng ngang đều sử dụng `Wrap`, `Flexible`, `Expanded` và `TextOverflow.ellipsis`. |

---

## 4. DANH SÁCH TỆP TIN THAY ĐỔI VÀ BỔ SUNG

### 4.1. `mobile/lib/screens/dashboard/parent_dashboard_screen.dart`
- Tái cấu trúc toàn bộ cây Widget theo 4 nhóm chức năng A, B, C, D.
- Tích hợp `NoiseService.getUnacknowledgedAlerts()` để kéo dữ liệu cảnh báo vi phạm thực tế từ backend `GET /api/ChildDeviceApi/noise-alerts`.
- Tích hợp `FaceAuthService.checkHasFace()` và `deleteFace()` cho tài khoản phụ huynh.
- Bổ sung `_showUnacknowledgedAlertsSheet()` cho phép phụ huynh duyệt và bấm "Xác nhận đã xem" từng cảnh báo ngay tại Dashboard.
- Cập nhật `_openNoiseMonitoring()` chỉ cho phép chọn thiết bị của con để mở `DeviceDetailScreen`, loại bỏ hoàn toàn việc mở micro đo trên điện thoại phụ huynh.

### 4.2. `mobile/lib/screens/device/device_detail_screen.dart`
- Tại khu vực Giám sát tiếng ồn:
  - Nếu là Phụ huynh (`canManage == true`): Hiển thị thẻ thông tin *"Nguyên Tắc Giám Sát Phụ Huynh: Phụ huynh theo dõi dữ liệu do máy con gửi lên và quản lý ngưỡng. Ứng dụng không kích hoạt microphone trên máy phụ huynh."*
  - Nếu là Trẻ em (`canManage == false`): Hiển thị nút *"Bắt Đầu Đo Tiếng Ồn"* để trẻ tự thực hiện phiên đo.

### 4.3. `mobile/lib/screens/qr/qr_scanner_screen.dart`
- Chuẩn hóa thuật ngữ: Sửa *"chữ ký số FNV-1a"* thành *"mã kiểm tra toàn vẹn (checksum FNV-1a)"*.
- Phân biệt hành vi nút tiếng ồn sau khi quét trúng thiết bị:
  - Phụ huynh: Hiển thị nút *"Xem Giám Sát Tiếng Ồn & Ngưỡng"* (chuyển sang `DeviceDetailScreen`).
  - Trẻ em: Hiển thị nút *"Đo Tiếng Ồn Thiết Bị Này"* (`NoiseMeterScreen` với `isParentViewer: false`).

### 4.4. `mobile/test/parent_dashboard_redesign_test.dart`
- Bộ test tự động chuyên sâu mới gồm **13 kịch bản kiểm thử**:
  - Kiểm tra loại bỏ thuật ngữ Task 04 và thanh 3 nút ngang.
  - Kiểm tra sự hiện diện đầy đủ của 4 nhóm A, B, C, D.
  - Kiểm tra phụ huynh KHÔNG có nút đo microphone cục bộ.
  - Kiểm tra tính cô lập và cam kết bảo mật Face AI phụ huynh.
  - Kiểm tra vị trí khu vực xác minh JWT.
  - Kiểm thử giao diện không tràn viền trên 4 độ phân giải (320x640, 360x800, 393x852, 430x932) tại 2 mức font scale (1.0 và 1.3).

---

## 5. BẰNG CHỨNG KIỂM THỬ TỰ ĐỘNG (TEST EVIDENCE)

### 5.1. Kết Quả Kiểm Thử File Mới `parent_dashboard_redesign_test.dart`
```
00:00 +0: loading D:/haha/NguyenDucChiNguyen_1486/mobile/test/parent_dashboard_redesign_test.dart
00:00 +0: Task 04.5: Parent Dashboard Redesign & Role Separation Tests Removes Task 04 grading jargon and 3-button horizontal hub
00:00 +1: Task 04.5: Parent Dashboard Redesign & Role Separation Tests Renders 4 functional groups: Tổng Quan, Quản Lý Trẻ Em, Theo Dõi & Quản Lý, Bảo Mật Tài Khoản
00:00 +2: Task 04.5: Parent Dashboard Redesign & Role Separation Tests Parent does NOT have a local microphone measurement trigger on Parent Dashboard
00:00 +3: Task 04.5: Parent Dashboard Redesign & Role Separation Tests Section D: Personal Face AI is isolated to Parent account and disclaims Child isolation
00:01 +4: Task 04.5: Parent Dashboard Redesign & Role Separation Tests Technical JWT Verification section is cleanly located in developer area
00:01 +5: Task 04.5: Multi-Viewport Responsive Tests on Redesigned Parent Dashboard ParentDashboardScreen renders cleanly on 320.0x640.0 at scale 1.0
00:01 +6: Task 04.5: Multi-Viewport Responsive Tests on Redesigned Parent Dashboard ParentDashboardScreen renders cleanly on 320.0x640.0 at scale 1.3
00:01 +7: Task 04.5: Multi-Viewport Responsive Tests on Redesigned Parent Dashboard ParentDashboardScreen renders cleanly on 360.0x800.0 at scale 1.0
00:01 +8: Task 04.5: Multi-Viewport Responsive Tests on Redesigned Parent Dashboard ParentDashboardScreen renders cleanly on 360.0x800.0 at scale 1.3
00:01 +9: Task 04.5: Multi-Viewport Responsive Tests on Redesigned Parent Dashboard ParentDashboardScreen renders cleanly on 393.0x852.0 at scale 1.0
00:01 +10: Task 04.5: Multi-Viewport Responsive Tests on Redesigned Parent Dashboard ParentDashboardScreen renders cleanly on 393.0x852.0 at scale 1.3
00:01 +11: Task 04.5: Multi-Viewport Responsive Tests on Redesigned Parent Dashboard ParentDashboardScreen renders cleanly on 430.0x932.0 at scale 1.0
00:01 +12: Task 04.5: Multi-Viewport Responsive Tests on Redesigned Parent Dashboard ParentDashboardScreen renders cleanly on 430.0x932.0 at scale 1.3
00:01 +13: All tests passed!
```
**Kết quả:** `13/13 tests passed (100%)`.

### 5.2. Kết Quả Toàn Bộ Test Suite Dự Án (`flutter test`)
```
00:04 +80: All tests passed!
```
**Chi tiết 80 bài kiểm tra thành công:**
- `parent_dashboard_redesign_test.dart`: 13 tests.
- `child_account_test.dart`: 9 tests.
- `noise_control_test.dart`: 11 tests.
- `device_crud_test.dart`: 19 tests.
- `widget_test.dart`: 5 tests.
- Cùng các bài kiểm tra giao diện và responsive đa tỉ lệ khác.

### 5.3. Phân Tích Tĩnh Mã Nguồn (`flutter analyze`)
```
Analyzing mobile...                                             
No issues found! (ran in 2.0s)
```
**Kết quả:** Hoàn toàn sạch lỗi (0 cảnh báo, 0 lỗi cú pháp hay lint).

---

## 6. DANH MỤC BLOCKER VÀ BẢO VỆ GIỚI HẠN

1. **Yêu Cầu Đo Từ Xa (Remote Request Trigger):**
   - **Trạng thái:** `BLOCKED`.
   - **Nguyên nhân:** Backend thiếu giao thức push thời gian thực (FCM Data Push / SignalR Hub).
   - **Xử lý:** Ứng dụng hiển thị trung thực nhãn `REMOTE REQUEST: BLOCKED` và hộp thoại kỹ thuật giải thích minh bạch, tuyệt đối không tạo nút giả lập request thành công.
2. **Bảo Vệ Quyền Riêng Tư Microphone:**
   - **Trạng thái:** `HOÀN TẤT`.
   - **Xử lý:** Không tự bật micro, không nghe lén, không ghi âm thô, không cho phụ huynh bấm đo tiếng ồn bằng micro của phụ huynh.
3. **Tính Toàn Vẹn Backend Nhóm:**
   - **Trạng thái:** `READ-ONLY TUYỆT ĐỐI`.
   - **Xử lý:** Thư mục `backend-group/nhom13` và cơ sở dữ liệu SQL Server không bị thay đổi bất kỳ dòng mã nào. Không commit hoặc push git.

---

## 7. KẾT LUẬN

Nhiệm vụ **TASK 04.5: PARENT DASHBOARD ROLE-BASED REDESIGN** đã hoàn thành xuất sắc toàn bộ các mục tiêu đặt ra:
- Chuyển hóa giao diện Dashboard Phụ huynh trở nên chuyên nghiệp, thanh thoát, đúng vai trò quản trị và bảo vệ an toàn cho trẻ.
- Khắc phục triệt để vấn đề phụ huynh đo tiếng ồn bằng micro của chính mình.
- Tách bạch rõ ràng chức năng người dùng thông thường và công cụ kiểm thử kỹ thuật.
- Đảm bảo 100% tính tương thích ngược với toàn bộ các tính năng CRUD, QR, Face AI và hệ thống test tự động hiện hữu.
