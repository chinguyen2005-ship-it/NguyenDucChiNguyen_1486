# BÁO CÁO KỸ THUẬT: ĐÁNH GIÁ KHẢ NĂNG ĐIỀU KHIỂN ĐO TIẾNG ỒN TỪ XA VÀ CHUYỂN ĐỔI MÔ HÌNH QUẢN TRỊ PARENT-CONTROLLED
**Mã Nhiệm Vụ:** TASK 04.4  
**Dự Án:** KidGuard — Quản Lý Thiết Bị Trẻ Em (Nhóm 13)  
**Đường Dẫn Dự Án:** `D:\haha\NguyenDucChiNguyen_1486`  
**Ngày Thực Hiện:** 22/10/2026  
**Trạng Thái:** **HOÀN TẤT TRIỂN KHAI FRONTEND & AUDIT TOÀN DIỆN (BACKEND READ-ONLY GIỮ NGUYÊN)**

---

## 1. TỔNG QUAN VÀ KẾT LUẬN CỐT LÕI

### 1.1. Mục Tiêu Chuyển Đổi
Chuyển đổi tính năng đo tiếng ồn từ mô hình **Child tự do đo/tự chỉnh sửa** sang mô hình **Parent quản lý trung tâm**:
1. **Phụ huynh (Parent):** Chọn thiết bị của con, xem lịch sử đo, theo dõi cảnh báo vượt ngưỡng, xác nhận đã xem cảnh báo, và quản lý trực tiếp ngưỡng an toàn (`NoiseThresholdDb`) qua API thật của hệ thống.
2. **Trẻ em (Child):** Chỉ thực hiện đo kiểm tra thủ công khi có sự chấp thuận minh bạch, tuyệt đối **KHÔNG** được chỉnh sửa ngưỡng an toàn, và có toàn quyền dừng đo bất kỳ lúc nào để giải phóng cảm biến microphone.

### 1.2. Kết Luận Khả Thi Về Đo Từ Xa (Remote Request Feasibility)
| Hạng Mục | Trạng Thái | Rationale Kỹ Thuật |
| :--- | :---: | :--- |
| **Yêu Cầu Đo Từ Xa (Parent $\to$ Child)** | 🔴 **BLOCKED** | Backend hoàn toàn thiếu kênh truyền lệnh downstream (Không có FCM Push, SignalR Hub, hay Command Queue). |
| **Quản Lý Ngưỡng Cảnh Báo (Parent Control)** | 🟢 **HOÀN TẤT** | Hoạt động 100% qua endpoint thực `PUT /api/ChildDeviceApi/{id}/noise-threshold`. |
| **Giám Sát Lịch Sử & Thống Kê (Parent Monitoring)** | 🟢 **HOÀN TẤT** | Hoạt động 100% qua endpoint thực `GET /api/ChildDeviceApi/{id}/noise`. |
| **Xác Nhận Cảnh Báo Vượt Ngưỡng (Alert Acknowledgment)** | 🟢 **HOÀN TẤT** | Hoạt động 100% qua endpoint thực `PUT /api/ChildDeviceApi/noise-alerts/{eventId}/ack`. |
| **Khóa Quyền Chỉnh Sửa Ngưỡng Của Trẻ (Child Guard)** | 🟢 **HOÀN TẤT** | Giao diện Child hiển thị `Chỉ đọc`, vô hiệu hóa thanh trượt ngưỡng, hiển thị thông báo minh bạch. |
| **Bảo Vệ Quyền Riêng Tư & An Toàn Microphone** | 🟢 **HOÀN TẤT** | Không ghi âm, không truyền audio thô, không nghe lén, giải phóng microphone ngay khi dừng. |

---

## 2. KIỂM TRA KHẢ NĂNG THỰC TẾ (BACKEND AUDIT)

Đội ngũ kỹ sư đã tiến hành audit toàn bộ mã nguồn của backend ASP.NET Core (`nhom13`) và ứng dụng Flutter:

### 2.1. Audit `ChildDeviceApiController.cs`
Kiểm tra chi tiết tất cả các endpoint liên quan đến tiếng ồn (`Noise`):
1. `GET /api/ChildDeviceApi/{id}/noise`:
   - Truy vấn lịch sử các bản ghi tiếng ồn của thiết bị thuộc quyền phụ huynh đăng nhập.
   - Trả về danh sách `NoiseEvents` và tổng hợp thống kê (`averageDecibel`, `peakDecibel`, `breachCount`).
   - **Đánh giá:** Kênh đọc dữ liệu lịch sử chuẩn xác.
2. `POST /api/ChildDeviceApi/{id}/noise`:
   - Nhận bản ghi đo đạc từ thiết bị (`meanDecibel`, `peakDecibel`, `durationSeconds`).
   - Tự động so sánh với `device.NoiseThresholdDb`. Nếu vượt ngưỡng $\to$ gửi email cảnh báo cho phụ huynh qua `EmailSender.cs`.
   - **Đánh giá:** Kênh đẩy dữ liệu đo đạc (Upstream Telemetry) từ Child lên Server.
3. `PUT /api/ChildDeviceApi/{id}/noise-threshold`:
   - Nhận payload JSON `{ "thresholdDb": 75.0 }`.
   - Kiểm tra thiết bị thuộc quyền của User (`UserId == currentUserId`).
   - Cập nhật trường `NoiseThresholdDb` trong SQL Server database.
   - **Đánh giá:** Endpoint thật hỗ trợ Parent quản lý ngưỡng từ xa.
4. `GET /api/ChildDeviceApi/noise-alerts`:
   - Lấy danh sách sự kiện tiếng ồn vượt ngưỡng chưa xử lý.
5. `PUT /api/ChildDeviceApi/noise-alerts/{eventId}/ack`:
   - Đánh dấu đã xác nhận xem cảnh báo (`IsAcknowledged = true`).

### 2.2. Kiểm Tra Kênh Truyền Ngược (Server/Parent $\to$ Child)
- **SignalR Hubs:** Kiểm tra thư mục `nhom13/Hubs` và file `Program.cs`. Hoàn toàn **KHÔNG CÓ** SignalR Hub nào được cấu hình (`app.MapHub(...)` không tồn tại trong backend).
- **Push Notification (FCM):** Không tìm thấy package `FirebaseAdmin` hoặc bất kỳ logic gửi push notification nào trong `nhom13.csproj` và `nhom13/Services/`.
- **Bảng Lưu Trữ Lệnh (Command Queue):** Trong Database `AppDbContext`, không có bảng `DeviceCommands` hoặc cơ chế polling an toàn nào để Child định kỳ kiểm tra xem có lệnh đo tiếng ồn từ Parent hay không.
- **Dịch Vụ Nền Hiện Có Trong `nhom13/Services/`:**
  - `EmailSender.cs`: Gửi mail thông báo.
  - `FaceRecognitionService.cs`: Đối sánh đặc trưng khuôn mặt.
  - `OtpService.cs`: Tạo và kiểm tra mã OTP xác thực 2 bước.
  - `TokenService.cs`: Cấp phát JWT token cho người dùng.

### 2.3. Kết Luận Audit
> [!IMPORTANT]
> **Hiện trạng:** Backend chỉ hỗ trợ kênh Upstream (`Child -> Server`) và Quản lý cấu hình (`Parent -> Server -> Database`).  
> **Kênh Downstream (`Server -> Child`):** Hoàn toàn **KHÔNG TỒN TẠI**.  
> **Tuân thủ quy tắc:** Không dùng polling lịch sử để giả lập lệnh đo, không tạo request giả. Do đó, tính năng "Yêu cầu đo từ xa" được đánh dấu chính thức là: **`REMOTE REQUEST: BLOCKED`**.

---

## 3. TRIỂN KHAI PHÂN QUYỀN MỤC TIÊU TRÊN FLUTTER

Tuân thủ nghiêm ngặt nguyên tắc **READ-ONLY Backend** và không tự ý thêm các endpoint giả tạo, toàn bộ giao diện đã được chuyển đổi để đáp ứng chuẩn mực phân quyền:

```
                            MÔ HÌNH PHÂN QUYỀN QUẢN TRỊ TIẾNG ỒN
 ┌────────────────────────────────────────────────────────────────────────────────────────┐
 │                                   PHỤ HUYNH (PARENT)                                   │
 │  • Chọn thiết bị con từ Parent Dashboard / Danh sách thiết bị                          │
 │  • Điều chỉnh ngưỡng cảnh báo (PUT /api/ChildDeviceApi/{id}/noise-threshold)           │
 │  • Xem báo cáo phân tích: Mức trung bình, Đỉnh tiếng ồn, Số lần vi phạm ngưỡng        │
 │  • Xác nhận cảnh báo vượt ngưỡng (PUT /api/ChildDeviceApi/noise-alerts/{id}/ack)       │
 │  • Nút "Yêu cầu đo từ xa": HIỂN THỊ TRẠNG THÁI [BLOCKED] + MODAL GIẢI THÍCH KỸ THUẬT   │
 └────────────────────────────────────────────────────────────────────────────────────────┘
                                              ▲
                                              │ (Dữ liệu Telemetry & Cảnh Báo)
                                              ▼
 ┌────────────────────────────────────────────────────────────────────────────────────────┐
 │                           BACKEND SQL SERVER (READ-ONLY)                               │
 │  • Lưu trữ: DeviceId, NoiseThresholdDb, MeanDb, PeakDb, RecordedAt, BreachFlag         │
 └────────────────────────────────────────────────────────────────────────────────────────┘
                                              ▲
                                              │ (Chỉ gửi thông số dB khi hoàn tất đo)
                                              ▼
 ┌────────────────────────────────────────────────────────────────────────────────────────┐
 │                                     TRẺ EM (CHILD)                                     │
 │  • Khởi chạy NoiseMeterScreen từ Child Dashboard với `isParentViewer: false`           │
 │  • Thanh trượt ngưỡng: KHÓA CHẶT (Read-Only) - "Ngưỡng an toàn do Phụ huynh quản lý"  │
 │  • Minh bạch Microphone: Thông báo rõ ràng chỉ đo cường độ dB, không ghi âm/nghe lén  │
 │  • Tự chủ quyền riêng tư: Tùy ý bấm "Dừng đo" để giải phóng cảm biến microphone       │
 └────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. CHI TIẾT CÁC TỆP NGUỒN ĐÃ HOÀN THIỆN

### 4.1. `mobile/lib/services/noise_service.dart`
- Bổ sung class `NoiseThresholdResult` đóng gói kết quả phản hồi từ API cập nhật ngưỡng.
- Hiện thực hàm `updateNoiseThreshold(int deviceId, double thresholdDb)`:
  - Gửi request `PUT /api/ChildDeviceApi/{deviceId}/noise-threshold`.
  - Body: `{"thresholdDb": thresholdDb}`.
  - Bắt lỗi token hết hạn, lỗi kết nối mạng và lỗi quyền sở hữu thiết bị (`403 Forbidden`).

### 4.2. `mobile/lib/screens/noise/noise_meter_screen.dart`
- Bổ sung tham số cấu hình phân quyền: `final bool isParentViewer`.
- **Nếu là Child (`isParentViewer: false`):**
  - **Khóa thanh điều chỉnh:** Slider ngưỡng bị vô hiệu hóa (`onChanged: null`).
  - **Nhãn hiển thị:** Hiển thị Badge cam `Chỉ đọc` kèm ghi chú: *"Ngưỡng an toàn do Phụ huynh quản lý. Trẻ em không thể chỉnh sửa."*
  - **Thông báo bảo vệ quyền riêng tư (Microphone Transparency Disclosure):** Hộp cảnh báo xanh dương khẳng định: *"Ứng dụng chỉ đo cường độ âm thanh (dB) trực tiếp trên thiết bị, tuyệt đối không ghi âm, không lưu trữ giọng nói và không truyền file âm thanh thô qua mạng."*
  - **Trạng thái đang đo:** Hiển thị biểu tượng microphone nhấp nháy (pulsating wave) minh bạch khi cảm biến đang hoạt động.
  - **Quyền dừng đo:** Nút "Dừng đo" màu đỏ giúp trẻ lập tức chấm dứt phiên đo và giải phóng `noise_meter` stream.
- **Nếu là Parent (`isParentViewer: true`):**
  - Cho phép mở hộp thoại điều chỉnh nhanh ngưỡng đo và đồng bộ trực tiếp lên hệ thống backend.
- **Tối ưu hiển thị responsive:** Sử dụng `Wrap` và các `Widget` đàn hồi, bảo đảm không bị tràn viền (`RenderFlex overflow`) trên mọi kích thước màn hình và trợ năng chữ lớn 1.3x.

### 4.3. `mobile/lib/screens/device/device_detail_screen.dart`
- Tích hợp khu vực quản lý chuyên sâu: **"Giám Sát Tiếng Ồn (Parent-Controlled)"**:
  1. **Hiển thị ngưỡng áp dụng:** Thẻ hiển thị giá trị ngưỡng hiện tại (`75.0 dB`) kèm nút "Đổi" (Quick Edit) gọi trực tiếp `updateNoiseThreshold`.
  2. **Banner trạng thái Remote:** Thẻ xám viền vàng cam với tiêu đề rõ ràng:  
     `REMOTE REQUEST: BLOCKED` — *"Backend chưa có kênh truyền lệnh thời gian thực tới thiết bị này."*
  3. **Nút Yêu Cầu Đo Từ Xa minh bạch:** Nút được thiết kế vô hiệu hóa có điều kiện với nhãn `Yêu Cầu Đo Từ Xa (Chưa khả dụng)`. Khi nhấn, hệ thống hiển thị Dialog kỹ thuật giải thích chi tiết:
     - Tại sao bị chặn: Thiếu cơ chế FCM Data Push hoặc SignalR Hub ở backend.
     - Cam kết đạo đức: KidGuard tuân thủ bảo vệ quyền trẻ em, không bí mật kích hoạt micro mà không có sự đồng ý của trẻ.
  4. **Lưới thống kê Telemetry:** Hiển thị số lượng đo, số lần vượt ngưỡng, mức trung bình dB và mức đỉnh cao nhất.
  5. **Xác nhận cảnh báo:** Nút "Xác nhận đã xem" cho từng sự kiện vượt ngưỡng (`PUT .../noise-alerts/{eventId}/ack`).
  6. **Phương án demo dự phòng:** Nút "Thực Hiện Đo Trên Thiết Bị Này" cho phép mở máy đo trực tiếp khi cần demo.

### 4.4. `mobile/lib/screens/dashboard/parent_dashboard_screen.dart` & `child_dashboard_screen.dart`
- `ParentDashboardScreen`: Khi phụ huynh nhấn nút "Tiếng Ồn", hệ thống mở BottomSheet cho phép phụ huynh chọn thiết bị của con để xem bảng giám sát chi tiết, hoặc mở công cụ đo độc lập.
- `ChildDashboardScreen`: Nút "Đo Tiếng Ồn" truyền rõ tham số `isParentViewer: false`, đảm bảo giao diện khóa ngưỡng ngay từ khi khởi động.

---

## 5. BẰNG CHỨNG KIỂM THỬ TỰ ĐỘNG (TEST EVIDENCE)

Bộ kiểm thử tự động chuyên sâu được thiết lập tại `mobile/test/noise_control_test.dart` và tích hợp vào test suite của dự án:

### 5.1. Kết Quả Chạy `noise_control_test.dart`
```
00:00 +0: Task 04.4: Model & Service Logic Tests NoiseThresholdResult models success and updated threshold correctly
00:00 +1: Task 04.4: Model & Service Logic Tests NoiseHistoryModel correctly parses telemetry stats and breach alerts
00:00 +2: Task 04.4: Model & Service Logic Tests NoiseService start and stop measurement manages lifecycle cleanly
00:00 +3: Task 04.4: Role-Based Noise Control in NoiseMeterScreen Parent view allows editing threshold and shows parent controls
00:00 +4: Task 04.4: Role-Based Noise Control in NoiseMeterScreen Child view locks threshold as Read-Only and shows privacy disclosure
00:00 +5: Task 04.4: DeviceDetailScreen Parent-Controlled Noise Hub Renders Parent-Controlled Noise section with BLOCKED remote badge and threshold edit
00:01 +6: Task 04.4: DeviceDetailScreen Parent-Controlled Noise Hub Child user sees Read-Only noise section without threshold change button
00:01 +7: Task 04.4: Multi-Viewport Responsive Tests DeviceDetailScreen renders cleanly on 320x640 Compact Phone at font scale 1.0 & 1.3
00:01 +8: Task 04.4: Multi-Viewport Responsive Tests DeviceDetailScreen renders cleanly on 360x800 Standard Phone at font scale 1.0 & 1.3
00:01 +9: Task 04.4: Multi-Viewport Responsive Tests DeviceDetailScreen renders cleanly on 393x852 iPhone 15 Class at font scale 1.0 & 1.3
00:02 +10: Task 04.4: Multi-Viewport Responsive Tests DeviceDetailScreen renders cleanly on 430x932 Large Phone at font scale 1.0 & 1.3
00:02 +11: All tests passed!
```
**Kết quả:** `11/11 tests passed (100%)`.

### 5.2. Kết Quả Kiểm Thử Toàn Dự Án (`flutter test`)
```
00:04 +67: All tests passed!
```
**Kết quả:** `67/67 tests passed (100%)` trên toàn bộ các bộ test: `device_crud_test.dart`, `child_account_test.dart`, `noise_control_test.dart`, và `widget_test.dart`.

### 5.3. Kết Quả Phân Tích Mã Nguồn (`flutter analyze`)
```
Analyzing mobile...                                             
No issues found! (ran in 1.4s)
```
**Kết quả:** `0 warnings, 0 errors`.

---

## 6. MA TRẬN ĐÁP ỨNG GIỚI HẠN BẮT BUỘC

| Giới Hạn Bắt Buộc | Tình Trạng | Cơ Chế Kiểm Soát Trong Mã Nguồn |
| :--- | :---: | :--- |
| **Không tự bật microphone bí mật** | 🛡️ **TUÂN THỦ 100%** | Microphone chỉ được gọi khi người dùng bấm rõ ràng vào nút "Bắt đầu đo". Không có `Timer` hoặc background service tự kích hoạt microphone. |
| **Không ghi âm hoặc truyền audio thô** | 🛡️ **TUÂN THỦ 100%** | Gói `noise_meter` chỉ trả về thông số biên độ sóng âm `meanDecibel` và `maxDecibel`. Không có file audio (.mp3, .wav) nào được ghi xuống bộ nhớ hay gửi lên server. |
| **Không tạo chức năng nghe lén** | 🛡️ **TUÂN THỦ 100%** | Backend và frontend đều không có giao thức truyền stream âm thanh (no audio streaming). Chỉ lưu số thực dB. |
| **Không dùng polling endpoint lịch sử để giả làm lệnh** | 🛡️ **TUÂN THỦ 100%** | Không có vòng lặp vô tận (infinite loop) gửi request thăm dò lịch sử. |
| **Không tự tạo request giả hiển thị đã gửi tới Child** | 🛡️ **TUÂN THỦ 100%** | Nút yêu cầu đo từ xa hiển thị trạng thái `Chưa khả dụng` và giải thích lý do kỹ thuật. |
| **Không tuyên bố realtime khi không có kênh truyền thật** | 🛡️ **TUÂN THỦ 100%** | Giao diện ghi rõ `REMOTE REQUEST: BLOCKED`. |
| **Không gửi dữ liệu đo mô phỏng lên database** | 🛡️ **TUÂN THỦ 100%** | Khi thiết bị đo thực tế, dữ liệu dB thực được gửi lên; khi đo mô phỏng offline, dữ liệu chỉ hiển thị cục bộ trên màn hình và không gọi API POST. |
| **Không sửa backend nhóm hoặc database** | 🛡️ **TUÂN THỦ 100%** | Thư mục `backend-group/nhom13` giữ nguyên 100% trạng thái ban đầu. Không sửa file C#, không chạy migration. |

---

## 7. ĐỀ XUẤT TỐI THIỂU CHO NHÓM BACKEND NẾU MUỐN HỖ TRỢ ĐO TỪ XA

Để hỗ trợ tính năng yêu cầu đo tiếng ồn từ xa trong tương lai mà vẫn đảm bảo tính khả thi kỹ thuật và an toàn quyền riêng tư, nhóm Backend có thể cân nhắc 2 phương án kiến trúc sau:

### Phương Án 1: Firebase Cloud Messaging (FCM Data Push) — Khuyến Nghị Cao Nhất
Phương án tối ưu nhất cho ứng dụng di động vì hoạt động được cả khi ứng dụng đang chạy nền (background) hoặc màn hình đang tắt:
1. **Cơ sở dữ liệu:**
   - Thêm trường `FcmToken NVARCHAR(512) NULL` vào bảng `ChildDevices`.
2. **Endpoint Backend bổ sung:**
   - `PUT /api/ChildDeviceApi/{id}/fcm-token`: Child app gửi token sau khi đăng nhập.
   - `POST /api/ChildDeviceApi/{id}/noise/request-measurement`: Phụ huynh gửi yêu cầu.
3. **Luồng hoạt động chuẩn đạo đức:**
   - Khi Backend nhận request từ Parent $\to$ gửi FCM Data Message tới Child device:
     ```json
     {
       "type": "NOISE_MEASUREMENT_REQUEST",
       "requestId": "uuid-v4",
       "requestedAt": "2026-10-22T04:30:00Z",
       "parentName": "Nguyen Van A"
     }
     ```
   - Khi Child nhận push $\to$ hiển thị Notification/Dialog minh bạch:  
     *"Phụ huynh yêu cầu đo tiếng ồn môi trường xung quanh. Bạn có đồng ý thực hiện đo trong 15 giây không? [Đồng Ý] [Từ Chối]"*.
   - Chỉ khi trẻ bấm **[Đồng Ý]**, hệ thống mới bật microphone và gửi kết quả lên `POST /api/ChildDeviceApi/{id}/noise`.

### Phương Án 2: ASP.NET Core SignalR (`DeviceControlHub`)
Phương án phù hợp cho môi trường kiểm thử realtime nội bộ:
1. **Thư viện Backend:** Cài đặt package `Microsoft.AspNetCore.SignalR.Common`.
2. **Tạo Hub:** `DeviceControlHub : Hub` hỗ trợ các hàm `SendMeasurementRequest(int deviceId)` và `JoinDeviceGroup(string deviceKey)`.
3. **Hạn chế:** Cả 2 máy phải mở ứng dụng đồng thời và duy trì kết nối WebSocket liên tục, gây tiêu hao pin nếu ứng dụng chạy nền.

---

## 8. TỔNG KẾT

Nhiệm vụ **TASK 04.4: PARENT-CONTROLLED NOISE CHECK** đã được thực hiện chính xác, trung thực và toàn diện:
- Xác minh tính khả thi thực tế của Backend: **`REMOTE REQUEST: BLOCKED`**.
- Hoàn thiện 100% vai trò quản lý của Phụ huynh đối với ngưỡng an toàn, lịch sử và cảnh báo qua API thực.
- Bảo vệ quyền riêng tư và quyền tự chủ của Trẻ em với cơ chế khóa quyền sửa ngưỡng và minh bạch hóa microphone.
- Bộ kiểm thử tự động 11 bài kiểm tra mới và toàn bộ 67 bài kiểm tra của dự án đều đạt kết quả tuyệt đối (100% Pass).
- Backend nhóm và Database SQL Server được bảo toàn nguyên vẹn.
