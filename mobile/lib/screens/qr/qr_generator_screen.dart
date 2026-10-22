import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/auth_models.dart';
import '../../models/device_model.dart';
import '../../models/qr_payload_model.dart';

class QrGeneratorScreen extends StatefulWidget {
  final ChildDeviceModel device;
  final UserProfile? currentUser;

  const QrGeneratorScreen({super.key, required this.device, this.currentUser});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  late KidGuardQrPayload _payload;
  Timer? _countdownTimer;
  int _remainingSeconds = 600;
  bool _showRawDetails = false;

  @override
  void initState() {
    super.initState();
    _generatePayload();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _generatePayload() {
    final parentUsername =
        widget.currentUser?.username ??
        widget.device.parentUsername ??
        'Parent';

    _payload = KidGuardQrPayload.create(
      deviceId: widget.device.id,
      childName: widget.device.childName,
      deviceName: widget.device.deviceName,
      parentUsername: parentUsername,
      expirySeconds: 600, // 10 phút
    );

    _remainingSeconds = _payload.remainingSeconds;

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds = _payload.remainingSeconds;
        if (_payload.isExpired) {
          timer.cancel();
        }
      });
    });
  }

  String _formatRemainingTime(int seconds) {
    if (seconds <= 0) return 'Hết hạn';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpired = _payload.isExpired;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mã QR Thiết Bị'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tạo mã mới',
            onPressed: () {
              setState(() {
                _generatePayload();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã làm mới mã định danh QR an toàn!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card info thiết bị
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.phone_android,
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.device.deviceName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Trẻ quản lý: ${widget.device.childName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            'Mã thiết bị ID: #${widget.device.id}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Khu vực hiển thị mã QR
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: isExpired ? 0.2 : 1.0,
                      child: QrImageView(
                        data: _payload.toQrString(),
                        version: QrVersions.auto,
                        size: 230.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    if (isExpired)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.timer_off_outlined,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Mã QR đã hết hạn',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _generatePayload();
                              });
                            },
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Làm mới ngay'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Trạng thái hiệu lực / Countdown
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isExpired
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isExpired ? Colors.red : Colors.green,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isExpired ? Icons.error_outline : Icons.timer_outlined,
                      size: 18,
                      color: isExpired ? Colors.red : Colors.green[800],
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isExpired
                            ? 'Mã QR đã hết hiệu lực bảo mật'
                            : 'Hiệu lực: ${_formatRemainingTime(_remainingSeconds)} (10p)',
                        style: TextStyle(
                          color: isExpired ? Colors.red : Colors.green[900],
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Nút sao chép mã payload
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _payload.toQrString()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép chuỗi mã QR vào khay nhớ tạm!'),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Sao Chép Mã QR (Dạng Text)'),
            ),
            const SizedBox(height: 8),

            // Toggle xem chi tiết an toàn
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showRawDetails = !_showRawDetails;
                });
              },
              icon: Icon(
                _showRawDetails ? Icons.expand_less : Icons.expand_more,
              ),
              label: Text(
                _showRawDetails
                    ? 'Ẩn chi tiết mã'
                    : 'Xem cấu trúc mã an toàn (JSON)',
              ),
            ),

            if (_showRawDetails) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payload an toàn (Không chứa Password/JWT):',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      _payload.toQrString(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.grey[800],
                      ),
                    ),
                    const Divider(),
                    Text(
                      '• Device ID: #${_payload.deviceId}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Trẻ: ${_payload.childName}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Thiết bị: ${_payload.deviceName}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Phụ huynh: ${_payload.parentUsername}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      '• Checksum (FNV-1a): ${_payload.checksum}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // Disclaimer & Security Policy
            Card(
              color: Colors.amber.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.amber.shade200),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.orange, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nguyên tắc bảo mật KidGuard:\n'
                        '• Mã QR chỉ chứa định danh thiết bị để tra cứu. Ứng dụng TUYỆT ĐỐI không chứa token JWT, mật khẩu, hay thông tin nhạy cảm.\n'
                        '• Mã băm FNV-1a là checksum phát hiện lỗi dữ liệu ngẫu nhiên, không phải chữ ký xác thực chống giả mạo. Toàn bộ quyền truy cập và kiểm tra thiết bị đều do Backend KidGuard đảm nhiệm.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
