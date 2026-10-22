import 'package:flutter/material.dart';

import '../../constants/api_constants.dart';
import '../../constants/app_colors.dart';
import '../../models/auth_models.dart';
import '../../models/device_model.dart';
import '../../services/auth_service.dart';
import '../../services/device_service.dart';
import '../../services/face_auth_service.dart';
import '../auth/login_screen.dart';
import '../face/face_auth_screen.dart';
import '../noise/noise_meter_screen.dart';
import '../qr/qr_generator_screen.dart';

class ChildDashboardScreen extends StatefulWidget {
  final UserProfile user;
  final DeviceService? deviceService;
  final FaceAuthService? faceAuthService;
  final List<ChildDeviceModel>? initialDevices;

  const ChildDashboardScreen({
    super.key,
    required this.user,
    this.deviceService,
    this.faceAuthService,
    this.initialDevices,
  });

  @override
  State<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends State<ChildDashboardScreen> {
  final _authService = AuthService();
  late final DeviceService _deviceService;
  late final FaceAuthService _faceAuthService;

  List<ChildDeviceModel> _devices = [];
  int _selectedDeviceIndex = 0;
  bool _isLoadingDevices = false;
  String? _devicesError;

  bool _hasFace = false;
  bool _isLoadingFaceStatus = false;

  String? _testResult;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _deviceService = widget.deviceService ?? DeviceService();
    _faceAuthService = widget.faceAuthService ?? FaceAuthService();
    _hasFace = widget.user.hasFace;
    if (widget.initialDevices != null) {
      _devices = widget.initialDevices!;
      _isLoadingDevices = false;
    } else {
      _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    await Future.wait([_loadAssignedDevices(), _checkFaceStatus()]);
  }

  Future<void> _loadAssignedDevices() async {
    setState(() {
      _isLoadingDevices = true;
      _devicesError = null;
    });

    final res = await _deviceService.getDevices();

    if (!mounted) return;
    setState(() {
      _isLoadingDevices = false;
      if (res.success && res.data != null) {
        _devices = res.data!;
        if (_selectedDeviceIndex >= _devices.length) {
          _selectedDeviceIndex = 0;
        }
      } else {
        _devicesError = res.message;
      }
    });
  }

  Future<void> _checkFaceStatus() async {
    setState(() => _isLoadingFaceStatus = true);
    final hasFace = await _faceAuthService.checkHasFace();
    if (!mounted) return;
    setState(() {
      _hasFace = hasFace;
      _isLoadingFaceStatus = false;
    });
  }

  Future<void> _handleDeleteFace() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 36,
        ),
        title: const Text('Xác Nhận Xóa Khuôn Mặt'),
        content: const Text(
          'Bạn có chắc chắn muốn xóa dữ liệu khuôn mặt đã đăng ký? '
          'Sau khi xóa, bạn sẽ không thể sử dụng tính năng Đăng nhập Face AI cho đến khi đăng ký lại.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa Dữ Liệu'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final res = await _faceAuthService.deleteFace();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? AppColors.success : AppColors.error,
      ),
    );

    if (res.success) {
      _checkFaceStatus();
    }
  }

  Future<void> _testBackendAuthorization(
    String url,
    String endpointName,
  ) async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final res = await _authService.testRoleEndpoint(url);

    if (!mounted) return;
    setState(() {
      _isTesting = false;
      _testResult =
          'Endpoint: $endpointName\nHTTP Status: ${res['statusCode']}\nResponse: ${res['data'] ?? res['error']}';
    });
  }

  Future<void> _handleLogout() async {
    await _authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  ChildDeviceModel? get _currentDevice {
    if (_devices.isEmpty || _selectedDeviceIndex >= _devices.length) {
      return null;
    }
    return _devices[_selectedDeviceIndex];
  }

  @override
  Widget build(BuildContext context) {
    final selectedDevice = _currentDevice;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Không Gian Của Trẻ Em'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _loadAllData,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Đăng xuất',
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ================= SECTION A: GREETING HEADER =================
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.cyan.shade100,
                        child: const Icon(
                          Icons.child_care_rounded,
                          size: 42,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Xin chào, ${widget.user.fullName}!',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tài khoản: @${widget.user.username}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.cyan.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.cyan.shade300),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              color: AppColors.secondary,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'VAI TRÒ: TRẺ EM (CHILD ROLE)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
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

              // ================= SECTION B: MY ASSIGNED DEVICE =================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_android_rounded,
                          color: AppColors.secondary,
                          size: 22,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Thiết Bị Của Tôi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_devices.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '${_devices.length} máy',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (_isLoadingDevices) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ] else if (_devicesError != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Lỗi tải thiết bị: $_devicesError',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadAssignedDevices,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ] else if (_devices.isEmpty) ...[
                // Empty State thân thiện cho Child
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 20,
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.grey.shade100,
                          child: Icon(
                            Icons.phonelink_erase_rounded,
                            size: 32,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa Có Thiết Bị Nào Được Gán',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Hãy nhờ ba mẹ mở KidGuard trên máy phụ huynh, tạo thiết bị và điền tên tài khoản của bạn (${widget.user.username}) để kết nối nhé!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _loadAssignedDevices,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Kiểm tra lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Bộ chọn máy nếu Child được gán nhiều máy
                if (_devices.length > 1) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_devices.length, (idx) {
                        final d = _devices[idx];
                        final isSelected = idx == _selectedDeviceIndex;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8, bottom: 8),
                          child: ChoiceChip(
                            label: Text(d.deviceName),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedDeviceIndex = idx);
                              }
                            },
                            selectedColor: Colors.cyan.shade100,
                          ),
                        );
                      }),
                    ),
                  ),
                ],

                // Thẻ thông tin máy hiện tại
                if (selectedDevice != null)
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: selectedDevice.isLocked
                                    ? Colors.red.shade100
                                    : Colors.cyan.shade100,
                                child: Icon(
                                  selectedDevice.isLocked
                                      ? Icons.lock_rounded
                                      : Icons.phone_android_rounded,
                                  color: selectedDevice.isLocked
                                      ? Colors.red.shade700
                                      : AppColors.secondary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      selectedDevice.deviceName,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Mã thiết bị: #${selectedDevice.id} • Quản lý: ${selectedDevice.parentUsername ?? "Phụ huynh"}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Trạng thái khóa & giới hạn
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedDevice.isLocked
                                      ? Colors.red.shade50
                                      : Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selectedDevice.isLocked
                                        ? Colors.red.shade200
                                        : Colors.green.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      selectedDevice.isLocked
                                          ? Icons.lock_outline
                                          : Icons.check_circle_outline,
                                      size: 16,
                                      color: selectedDevice.isLocked
                                          ? Colors.red.shade700
                                          : Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      selectedDevice.isLocked
                                          ? 'ĐANG KHÓA TỪ XA'
                                          : 'HOẠT ĐỘNG',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: selectedDevice.isLocked
                                            ? Colors.red.shade800
                                            : Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.blue.shade200,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 16,
                                      color: Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Hạn mức: ${selectedDevice.formattedScreenTime}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          Text(
                            '• Ngưỡng tiếng ồn an toàn: ${selectedDevice.noiseThresholdDb.toInt()} dB (Chỉ phụ huynh có quyền chỉnh ngưỡng)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (selectedDevice.isLocked) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Thiết bị đang bị khóa bởi phụ huynh. Bạn hãy tạm thời nghỉ ngơi hoặc liên hệ ba mẹ để mở khóa.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 20),

              // ================= SECTION C: ADVANCED FEATURES HUB =================
              const Row(
                children: [
                  Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tính Năng Nâng Cao Dành Cho Bạn',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Feature 1: Face AI for Child
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.face_rounded,
                              color: Colors.deepPurple,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bảo Mật Khuôn Mặt (Face AI)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _isLoadingFaceStatus
                                    ? const Text(
                                        'Đang kiểm tra...',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _hasFace
                                                ? Icons.check_circle
                                                : Icons.info_outline,
                                            size: 14,
                                            color: _hasFace
                                                ? Colors.green
                                                : Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              _hasFace
                                                  ? 'Đã đăng ký khuôn mặt'
                                                  : 'Chưa đăng ký khuôn mặt',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _hasFace
                                                    ? Colors.green.shade800
                                                    : Colors.orange.shade800,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Đăng ký mẫu khuôn mặt của chính bạn để đăng nhập nhanh chóng bằng camera trước (mô hình ArcFace AI).',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FaceAuthScreen(
                                    mode: FaceAuthMode.register,
                                    initialUsername: widget.user.username,
                                  ),
                                ),
                              );
                              _checkFaceStatus();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 18,
                            ),
                            label: Text(
                              _hasFace ? 'Cập Nhật Mẫu' : 'Đăng Ký Ngay',
                            ),
                          ),
                          if (_hasFace)
                            OutlinedButton.icon(
                              onPressed: _handleDeleteFace,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Xóa Mẫu'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Feature 2: Noise Meter for Child
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.graphic_eq_rounded,
                              color: Colors.teal,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Đo Tiếng Ồn Xung Quanh (Noise Meter)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  selectedDevice != null
                                      ? 'Ghi nhận cho máy: ${selectedDevice.deviceName}'
                                      : 'Đo thử nghiệm môi trường',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Kiểm tra độ ồn môi trường học tập và giải trí thời gian thực. '
                        'Số đo thật sẽ được gửi về để ba mẹ biết khi bạn ở nơi quá ồn.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NoiseMeterScreen(
                                device: selectedDevice,
                                isParentViewer: false,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 20,
                        ),
                        label: const Text('Mở Máy Đo Tiếng Ồn'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Feature 3: QR Device Code for Child
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.qr_code_2_rounded,
                              color: Colors.indigo,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mã QR Định Danh Máy (Device QR)',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Chia sẻ an toàn không mật khẩu',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Hiển thị mã QR chứa ID thiết bị và chữ ký số kiểm tra toàn vẹn để ba mẹ quét và nhận diện nhanh.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: selectedDevice != null
                            ? () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => QrGeneratorScreen(
                                      device: selectedDevice,
                                      currentUser: widget.user,
                                    ),
                                  ),
                                );
                              }
                            : () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Bạn chưa được gán thiết bị nào để tạo mã QR.',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.qr_code_rounded, size: 20),
                        label: const Text('Xem Mã QR Của Thiết Bị'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ================= SECTION D: SAFETY & PRIVACY NOTICE =================
              Card(
                color: Colors.lightBlue.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.lightBlue.shade200),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.security_rounded,
                            color: Colors.blueAccent,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Cam Kết An Toàn & Quyền Riêng Tư',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Camera: Chỉ mở khi bạn chủ động bấm chụp ảnh đăng ký khuôn mặt. Tuyệt đối không chụp ngầm.\n'
                        '• Microphone: Chỉ thu âm khi bạn bấm "Bắt Đầu Đo". Ứng dụng giải phóng micro ngay khi bạn rời màn hình.\n'
                        '• Không Ghi Âm: KidGuard chỉ đo cường độ to/nhỏ (dB), tuyệt đối không lưu file âm thanh cuộc trò chuyện.\n'
                        '• Phân quyền: Bạn không có quyền chỉnh sửa thời gian hay ngưỡng ồn; toàn bộ cấu hình an toàn do ba mẹ thiết lập.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ================= SECTION E: LIVE BACKEND AUTHORIZATION TEST =================
              const Text(
                'Kiểm Thử Phân Quyền Backend Thực Tế (JWT)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Xác minh token thật gửi tới các API backend yêu cầu quyền cụ thể:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isTesting
                        ? null
                        : () => _testBackendAuthorization(
                            ApiConstants.childDevices,
                            '/api/ChildDeviceApi',
                          ),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Test Devices (Kỳ vọng: 200)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isTesting
                        ? null
                        : () => _testBackendAuthorization(
                            ApiConstants.adminOnly,
                            '/api/Admin/users',
                          ),
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text('Test Admin-Only (Kỳ vọng: 403)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isTesting) ...[
                const Center(child: CircularProgressIndicator()),
              ] else if (_testResult != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _testResult!,
                    style: const TextStyle(
                      color: Colors.lightGreenAccent,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Project signature
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'KidGuard Nhóm 13 — Sinh viên: NguyenDucChiNguyen_1486',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
