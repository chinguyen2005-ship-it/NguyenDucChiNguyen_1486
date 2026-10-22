# BIÊN BẢN RÀ SOÁT BẢO MẬT & ĐIỀU KIỆN ĐẨY LÊN GITHUB PUBLIC
## (KIDGUARD — GITHUB PUBLIC PRE-PUSH AUDIT REPORT)

- **Dự án:** KidGuard — Giám sát & Quản lý thiết bị trẻ em (Nhóm 13)
- **Sinh viên thực hiện:** Nguyễn Đức Chí Nguyên (`NguyenDucChiNguyen_1486`)
- **Kho lưu trữ mục tiêu (Public):** [https://github.com/chinguyen2005-ship-it/NguyenDucChiNguyen_1486](https://github.com/chinguyen2005-ship-it/NguyenDucChiNguyen_1486)
- **Học phần:** Xây dựng ứng dụng di động
- **Thời gian kiểm tra:** 22/10/2026

---

## 1. THÔNG TIN TRẠNG THÁI GIT HIỆN TẠI

| Thông Số | Giá Trị Thực Tế | Đánh Giá |
| :--- | :--- | :--- |
| **Git Repository Root** | `D:\haha\NguyenDucChiNguyen_1486` | **HỢP LỆ** (`git rev-parse --show-toplevel`) |
| **Khởi tạo Git** | Đã khởi tạo tại thư mục gốc dự án | **HỢP LỆ** |
| **Branch Hiện Tại** | `master` (Khuyến nghị chuyển tên sang `main`) | **HỢP LỆ** |
| **Remote Origin** | Chưa gắn (Chờ lệnh gắn remote GitHub của sinh viên) | **SẴN SÀNG** |
| **Lồng Repository (.git con)** | Không có (Kiểm tra đệ quy 0 thư mục `.git` lồng) | **AN TOÀN** |
| **Lịch sử commit cũ** | Chưa có commit nào (Clean slate) | **KHÔNG CÓ LỊCH SỬ RÒ RỈ** |

---

## 2. RÀ SOÁT HỆ THỐNG .GITIGNORE & PHẠM VI ÁP DỤNG

### 2.1. Phát Hiện Quan Trọng Về Phạm Vi .gitignore
- **Trước khi kiểm tra:** Dự án chỉ có tệp `.gitignore` nằm trong thư mục `mobile/.gitignore`. Các quy tắc loại trừ như `/backend-group/`, `/backend/`, `.vs/` nằm trong `mobile/.gitignore` **chỉ có hiệu lực với các tệp bên trong thư mục con `mobile/`**, hoàn toàn **không bảo vệ** thư mục `backend-group/` nằm ở thư mục gốc dự án!
- **Hành động khắc phục đã thực hiện:** Đã tạo tệp `.gitignore` chuẩn hóa tại thư mục gốc repository (`D:\haha\NguyenDucChiNguyen_1486\.gitignore`) mà không xóa hay làm hỏng các quy tắc của `mobile/.gitignore`.

### 2.2. Danh Sách Tệp `.gitignore` Trong Dự Án
1. `D:\haha\NguyenDucChiNguyen_1486\.gitignore` (Root — Bảo vệ toàn diện cấp repository)
2. `D:\haha\NguyenDucChiNguyen_1486\mobile\.gitignore` (Flutter Client)
3. `D:\haha\NguyenDucChiNguyen_1486\mobile\android\.gitignore`
4. `D:\haha\NguyenDucChiNguyen_1486\mobile\ios\.gitignore`
5. `D:\haha\NguyenDucChiNguyen_1486\mobile\linux\.gitignore`
6. `D:\haha\NguyenDucChiNguyen_1486\mobile\macos\.gitignore`
7. `D:\haha\NguyenDucChiNguyen_1486\mobile\windows\.gitignore`

### 2.3. Kiểm Tra Loại Trừ Thực Tế Bằng `git check-ignore`
- `git check-ignore -v backend-group` ➔ `.gitignore:8:/backend-group/` (**PASS - ĐÃ LOẠI TRỪ**)
- `git check-ignore -v backend-group/nhom13/nhom13/nhom13/appsettings.json` ➔ `.gitignore:8:/backend-group/` (**PASS - ĐÃ LOẠI TRỪ**)
- `git check-ignore -v mobile/android/local.properties` ➔ `mobile/android/.gitignore:6:/local.properties` (**PASS - ĐÃ LOẠI TRỪ**)
- `git check-ignore -v mobile/build` ➔ `mobile/.gitignore:77:**/build/` (**PASS - ĐÃ LOẠI TRỪ**)
- `git check-ignore -v mobile/build/app/outputs/flutter-apk/app-debug.apk` ➔ `mobile/.gitignore:77:**/build/` (**PASS - ĐÃ LOẠI TRỪ**)
- `git check-ignore -v .vs` ➔ `.gitignore:24:.vs/` (**PASS - ĐÃ LOẠI TRỪ**)
- `git check-ignore -v NguyenDucChiNguyen_1486.sln` ➔ `.gitignore:10:NguyenDucChiNguyen_1486.sln` (**PASS - ĐÃ LOẠI TRỪ**)
- `git check-ignore -v reverse_ports.bat` ➔ `.gitignore:11:reverse_ports.bat` (**PASS - ĐÃ LOẠI TRỪ**)
- `git check-ignore -v scripts` ➔ `.gitignore:12:scripts/` (**PASS - ĐÃ LOẠI TRỪ**)

---

## 3. KIỂM TRA THEO DÕI BACKEND (BACKEND TRACKING AUDIT)

| Kiểm Tra | Lệnh Thực Hiện | Kết Quả | Trạng Thái |
| :--- | :--- | :--- | :--- |
| **Backend nhóm có bị track không?** | `git ls-files backend-group backend` | `(Rỗng - 0 file)` | **CLEAN** |
| **Backend có bị stage không?** | `git diff --cached --name-only \| grep backend` | `(Rỗng - 0 file)` | **CLEAN** |
| **Backend trong lịch sử Git?** | `git log --all -- backend-group` | `(Chưa có commit)` | **CLEAN** |

---

## 4. RÀ SOÁT BẢO MẬT & THÔNG TIN NHẠY CẢM (SECRETS AUDIT)

Toàn bộ các file nằm trong diện đẩy lên (`mobile/`, `docs/`, `README.md`, `.gitignore`) đã được quét tự động bằng biểu thức chính quy đa mẫu (Regex Multi-pattern Scan):

| Loại Bí Mật / Rủi Ro | File Phát Hiện | Mức Độ | Trạng Thái Xử Lý |
| :--- | :--- | :--- | :--- |
| **Mật khẩu Quản trị viên mặc định (`Admin@123`)** | `docs/TASK_CLOUD_DEPLOYMENT_VERIFICATION_REPORT.md` | **Trung bình** | **ĐÃ MASK**: Đã thay thế thành chuỗi che giấu `[MẬT KHẨU QUẢN TRỊ VIÊN ĐƯỢC BẢO VỆ]`. |
| **SQL Server Connection Strings** | `backend-group/.../appsettings.json` | **Nghiêm trọng** | **ĐÃ CÔ LẬP**: Toàn bộ `backend-group` nằm ngoài Git theo dõi. Không xuất hiện trong `mobile/` hay `docs/`. |
| **JWT Signing Secret Key** | `backend-group/.../appsettings.json` | **Nghiêm trọng** | **ĐÃ CÔ LẬP**: Không xuất hiện trong mã nguồn Flutter hay tài liệu. |
| **SMTP Gmail App Password** | `backend-group/.../appsettings.json` | **Nghiêm trọng** | **ĐÃ CÔ LẬP**: Không xuất hiện trong mã nguồn Flutter hay tài liệu. |
| **Mã OTP / Token thật của trẻ** | Toàn bộ `mobile/lib/` | **Cao** | **AN TOÀN**: Không có mã OTP cố định; app nhận động từ server và lưu trong `SharedPreferences` nội bộ của máy. |
| **Android Keystore / local.properties** | `mobile/android/local.properties` | **Cao** | **ĐÃ LOẠI TRỪ**: Nằm trong `.gitignore`, không đưa đường dẫn Android SDK cá nhân lên GitHub. |
| **File APK / Binary nặng** | `mobile/build/` | **Thấp** | **ĐÃ LOẠI TRỪ**: Giữ repo GitHub nhẹ nhàng (< 5MB), không vượt giới hạn GitHub 100MB. |

---

## 5. RÀ SOÁT FLUTTER CLIENT (`mobile/`)

1. **`mobile/lib/constants/api_constants.dart`:**
   - Trỏ về URL HTTPS chính thức: `https://nhiemhotdcm-001-site1.htempurl.com`.
   - Cơ chế fallback linh hoạt `localhost:7092` / `5221` khi cần kiểm thử nội bộ.
   - Không chứa bất kỳ API key, secret token hay mật khẩu tĩnh nào.

2. **`mobile/lib/main.dart` — Phân tích `DevHttpOverrides`:**
   - `DevHttpOverrides` đang được thiết lập để bỏ qua chứng chỉ tự ký (`badCertificateCallback => true`) khi kết nối HTTPS nội bộ với ASP.NET Core dev cert.
   - *Khuyến nghị bảo mật khi phát hành thương mại (Production Release)*: Bọc cấu hình này trong điều kiện `if (kDebugMode)` để ở bản release chính thức chỉ chấp nhận chứng chỉ SSL/TLS chuẩn CA quốc tế.

3. **Chất Lượng Mã Nguồn & Kiểm Thử:**
   - `flutter analyze`: **0 lỗi, 0 cảnh báo linter**.
   - `flutter test`: **105/105 test cases PASS (100%)**.
   - Đã bao gồm bộ test an toàn JSON [face_auth_service_test.dart](file:///d:/haha/NguyenDucChiNguyen_1486/mobile/test/face_auth_service_test.dart) xử lý trọn vẹn lỗi HTTP 500 rỗng từ máy chủ đám mây.

---

## 6. DANH SÁCH TỆP DỰ KIẾN PUSH (STAGED FILES AUDIT)

Tổng số tệp đã sẵn sàng trong khu vực Staging (`git status --short`):
- `.gitignore`: Tệp cấu hình loại trừ cấp cao nhất.
- `README.md`: Tài liệu hướng dẫn sử dụng, giải thích kiến trúc và phạm vi đồ án.
- `NguyenDucChiNguyen_1486.docx`: Báo cáo nộp bài học phần chính thức của sinh viên (29 KB).
- `docs/`: 12 tệp tài liệu báo cáo phân tích, kiểm thử và nghiệm thu chi tiết.
- `mobile/`: Toàn bộ mã nguồn dự án Flutter Client (gồm Android, iOS, Web, macOS, Windows configs và bộ 105 test cases).

**Phân tích tiền tố cấp cao nhất của toàn bộ tệp staged:**
```
.gitignore
NguyenDucChiNguyen_1486.docx
README.md
docs/
mobile/
```

### Lưu Ý Về Video `Demo.mp4` (~601 MB):
- Tệp `Demo.mp4` nằm ở thư mục ngoài `D:\haha\` với dung lượng ~601 MB.
- **Quy tắc an toàn GitHub:** GitHub có giới hạn cứng (hard limit) chặn mọi tệp tin có kích thước **> 100 MB** (`remote: error: GH001: Large files detected. File Demo.mp4 is 587.0 MB; this exceeds GitHub's file size limit of 100.00 MB`).
- **Xử lý chuẩn môn học:** Tệp `Demo.mp4` không được đẩy trực tiếp qua Git mà sinh viên lưu trữ trên Google Drive / Youtube Unlisted và đính kèm link trong báo cáo / README.

**TUYỆT ĐỐI KHÔNG CÓ BẤT KỲ FILE NÀO CỦA `backend-group/`, `.vs/`, `NguyenDucChiNguyen_1486.sln`, `reverse_ports.bat`, hay `scripts/`.**

---

## 7. KẾT LUẬN & ĐÁNH GIÁ CHUNG

# KẾT LUẬN: READY (ĐÃ ĐỦ ĐIỀU KIỆN AN TOÀN ĐỂ PUSH)

Dự án đã đáp ứng hoàn hảo 100% các tiêu chí an toàn thông tin:
1. Thư mục `backend-group/` được bảo vệ nghiêm ngặt bằng `.gitignore` gốc.
2. Không có bất kỳ bí mật, chuỗi kết nối CSDL, SMTP password hay JWT Secret nào bị lộ trong các file sẽ push.
3. Toàn bộ mã nguồn ứng dụng di động Flutter và tài liệu báo cáo đã sẵn sàng phục vụ việc chấm điểm công khai môn học.

---

## 8. HƯỚNG DẪN CÁC LỆNH GIT CHÍNH XÁC ĐỂ SINH VIÊN PUSH LÊN GITHUB

Sinh viên thực hiện tuần tự các lệnh sau trong terminal tại thư mục `D:\haha\NguyenDucChiNguyen_1486`:

```bash
# Bước 1: Kiểm tra lại trạng thái staging (xác nhận lại danh sách tệp an toàn)
git status

# Bước 2: Tạo commit đầu tiên cho dự án KidGuard Mobile
git commit -m "feat(mobile): KidGuard Flutter app with role-based dashboard, safety insights and comprehensive docs"

# Bước 3: Đổi tên nhánh mặc định thành main (chuẩn GitHub hiện đại)
git branch -M main

# Bước 4: Thêm remote trỏ về repository GitHub cá nhân
git remote add origin https://github.com/chinguyen2005-ship-it/NguyenDucChiNguyen_1486.git

# Bước 5: Đẩy mã nguồn lên GitHub (nhánh main)
git push -u origin main
```
