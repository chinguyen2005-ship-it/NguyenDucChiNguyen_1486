import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/auth_models.dart';
import '../../models/device_model.dart';
import '../../models/qr_payload_model.dart';
import '../../services/auth_service.dart';
import '../../services/device_service.dart';
import '../../services/storage_service.dart';
import '../device/device_detail_screen.dart';
import '../noise/noise_meter_screen.dart';

class QrScannerScreen extends StatefulWidget {
  final UserProfile? currentUser;

  const QrScannerScreen({super.key, this.currentUser});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  late final MobileScannerController _controller;
  final DeviceService _deviceService = DeviceService();
  final AuthService _authService = AuthService();
  UserProfile? _currentUser;

  bool _isProcessing = false;
  bool _isTorchOn = false;
  CameraFacing _cameraFacing = CameraFacing.back;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
    if (_currentUser == null) {
      _loadCurrentUser();
    }
  }

  Future<void> _loadCurrentUser() async {
    final profile =
        await _authService.getCurrentUser() ?? await StorageService.getUser();
    if (profile != null && mounted) {
      setState(() => _currentUser = profile);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        _processQrContent(rawValue);
        break;
      }
    }
  }

  Future<void> _processQrContent(String rawValue) async {
    setState(() => _isProcessing = true);

    // 1. Giải mã và kiểm tra cấu trúc/chữ ký FNV-1a
    final payload = KidGuardQrPayload.fromQrString(rawValue);

    if (payload == null) {
      if (!mounted) return;
      _showErrorDialog(
        title: 'Mã QR Không Hợp Lệ',
        message: 'Mã QR này không thuộc hệ thống KidGuard hoặc mã kiểm tra toàn vẹn (checksum FNV-1a) không khớp (dữ liệu có thể đã bị sửa đổi).',
      );
      return;
    }

    // 2. Kiểm tra thời hạn hiệu lực
    if (payload.isExpired) {
      if (!mounted) return;
      _showErrorDialog(
        title: 'Mã QR Đã Hết Hạn',
        message: 'Mã QR định danh này đã hết hạn 10 phút. Vui lòng làm mới mã trên thiết bị phát để quét lại.',
      );
      return;
    }

    // 3. Tra cứu thiết bị trên Backend KidGuard
    ChildDeviceModel? matchedDevice;
    String? lookupError;

    try {
      final res = await _deviceService.getDeviceById(payload.deviceId);
      if (res.success && res.data != null) {
        matchedDevice = res.data;
      } else {
        lookupError = res.message;
      }
    } catch (e) {
      lookupError = e.toString().replaceAll('Exception: ', '');
    }

    if (!mounted) return;

    // 4. Hiển thị kết quả giải mã và thông tin thiết bị
    _showResultBottomSheet(payload, matchedDevice, lookupError);
  }

  void _showErrorDialog({required String title, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 48,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() => _isProcessing = false);
            },
            child: const Text('Thử Lại'),
          ),
        ],
      ),
    );
  }

  void _showResultBottomSheet(
    KidGuardQrPayload payload,
    ChildDeviceModel? device,
    String? lookupError,
  ) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 28),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Xác Thực Mã QR Thành Công',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Thông tin giải mã từ QR
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dữ liệu giải mã từ mã QR:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Thiết bị: ${payload.deviceName} (ID: #${payload.deviceId})',
                    ),
                    Text('• Trẻ sở hữu: ${payload.childName}'),
                    Text('• Phụ huynh liên kết: ${payload.parentUsername}'),
                    Text('• Còn hiệu lực: ${payload.remainingSeconds} giây'),
                    Text(
                      '• Checksum FNV-1a: ${payload.checksum}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Kết quả đối chiếu với Backend SQL Server
              if (device != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_done,
                        color: Colors.green,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Đã khớp với Cơ sở dữ liệu KidGuard',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              'Khoá: ${device.isLocked ? "Đang khoá" : "Mở khoá"} | Giới hạn: ${device.screenTimeLimitMinutes}p | Ngưỡng ồn: ${device.noiseThresholdDb.toInt()}dB',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        color: Colors.orange,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          lookupError ??
                              'Không tìm thấy thiết bị #${payload.deviceId} trên server hoặc bạn không có quyền truy cập.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),
              // Thông báo nguyên tắc bảo mật và giới hạn backend
              Text(
                'Lưu ý: Mã QR dùng để xác thực định danh và tra cứu nhanh. Backend không hỗ trợ endpoint tự động ghép nối (pair) tài khoản Parent/Child qua QR.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 18),

              // Các nút hành động
              if (device != null) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    final effectiveUser =
                        _currentUser ??
                        UserProfile(
                          id: payload.parentUsername,
                          username: payload.parentUsername,
                          email: '${payload.parentUsername}@kidguard.local',
                          fullName: payload.parentUsername,
                          roles: const ['Parent'],
                          emailConfirmed: true,
                        );
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DeviceDetailScreen(
                          device: device,
                          currentUser: effectiveUser,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Xem Chi Tiết Thiết Bị Này'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    final effectiveUser =
                        _currentUser ??
                        UserProfile(
                          id: payload.parentUsername,
                          username: payload.parentUsername,
                          email: '${payload.parentUsername}@kidguard.local',
                          fullName: payload.parentUsername,
                          roles: const ['Parent'],
                          emailConfirmed: true,
                        );
                    if (_currentUser?.isChild == true) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => NoiseMeterScreen(
                            device: device,
                            isParentViewer: false,
                          ),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DeviceDetailScreen(
                            device: device,
                            currentUser: effectiveUser,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.graphic_eq_rounded),
                  label: Text(
                    _currentUser?.isChild == true
                        ? 'Đo Tiếng Ồn Thiết Bị Này'
                        : 'Xem Giám Sát Tiếng Ồn & Ngưỡng',
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  setState(() => _isProcessing = false);
                },
                child: const Text('Tiếp Tục Quét'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showManualInputDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nhập Mã QR Thủ Công'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dán chuỗi JSON của mã QR hoặc ID thiết bị để kiểm tra khi không dùng camera:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '{"t":"kidguard_device", ...}',
                hintStyle: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = textController.text.trim();
              Navigator.of(ctx).pop();
              if (text.isNotEmpty) {
                _processQrContent(text);
              }
            },
            child: const Text('Xác Thực'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét Mã QR Thiết Bị'),
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            tooltip: 'Bật/Tắt Đèn Flash',
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            tooltip: 'Đổi Camera',
            onPressed: () async {
              await _controller.switchCamera();
              setState(() {
                _cameraFacing = _cameraFacing == CameraFacing.back
                    ? CameraFacing.front
                    : CameraFacing.back;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Nhập mã thủ công',
            onPressed: _showManualInputDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera scanner view
          MobileScanner(controller: _controller, onDetect: _handleBarcode),

          // Viewfinder Overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _isProcessing ? Colors.orange : Colors.greenAccent,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Scanning guideline / indicator
          Positioned(
            top: 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hướng camera vào mã QR thiết bị KidGuard để nhận diện an toàn',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Bar for fallback
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _showManualInputDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.edit_note),
              label: const Text('Nhập/Dán Chuỗi QR Bằng Tay'),
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Đang xác thực mã định danh & kiểm tra checksum...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
