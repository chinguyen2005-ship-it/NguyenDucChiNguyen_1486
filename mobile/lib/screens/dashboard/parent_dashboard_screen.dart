import 'package:flutter/material.dart';

import '../../constants/api_constants.dart';
import '../../constants/app_colors.dart';
import '../../models/auth_models.dart';
import '../../models/device_model.dart';
import '../../models/noise_model.dart';
import '../../services/auth_service.dart';
import '../../services/device_service.dart';
import '../../services/face_auth_service.dart';
import '../../services/noise_service.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../device/device_detail_screen.dart';
import '../device/device_form_screen.dart';
import '../device/device_list_screen.dart';
import '../face/face_auth_screen.dart';
import '../qr/qr_scanner_screen.dart';
import '../safety/family_safety_insights_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  final UserProfile user;

  const ParentDashboardScreen({super.key, required this.user});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  final _authService = AuthService();
  final _deviceService = DeviceService();
  final _noiseService = NoiseService();
  final _faceAuthService = FaceAuthService();

  List<ChildDeviceModel> _devices = [];
  List<NoiseEventModel> _unacknowledgedAlerts = [];
  bool _isLoadingDevices = false;
  String? _devicesError;

  bool _hasFace = false;

  String? _testResult;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoadingDevices = true;
      _devicesError = null;
    });

    final devFuture = _deviceService.getDevices();
    final alertsFuture = _noiseService.getUnacknowledgedAlerts();
    final faceFuture = _faceAuthService.checkHasFace();

    final results = await Future.wait([devFuture, alertsFuture, faceFuture]);

    if (!mounted) return;
    final devRes = results[0] as ApiResponse<List<ChildDeviceModel>>;
    final alertsRes = results[1] as List<NoiseEventModel>;
    final hasFaceRes = results[2] as bool;

    setState(() {
      _isLoadingDevices = false;
      if (devRes.success) {
        _devices = devRes.data ?? [];
      } else {
        _devicesError = devRes.message;
      }
      _unacknowledgedAlerts = alertsRes;
      _hasFace = hasFaceRes;
    });
  }

  Future<void> _handleDeleteParentFace() async {
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
          'Bạn có chắc muốn xóa dữ liệu khuôn mặt đã đăng ký cho tài khoản phụ huynh này? '
          'Sau khi xóa, bạn sẽ đăng nhập bằng mật khẩu hoặc mã OTP thay vì Face AI.',
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
            child: const Text('Xóa Mẫu'),
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
      final hasFace = await _faceAuthService.checkHasFace();
      if (mounted) setState(() => _hasFace = hasFace);
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

  Future<void> _navigateToAddDevice() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DeviceFormScreen(defaultParentUsername: widget.user.username),
      ),
    );
    if (added == true) {
      _loadAllData();
    }
  }

  List<_ChildAccountGroup> get _groupedChildren {
    final Map<String, _ChildAccountGroup> groups = {};

    for (final dev in _devices) {
      final rawUser = dev.childUsername?.trim();
      final hasUsername = rawUser != null && rawUser.isNotEmpty;
      final key = hasUsername
          ? 'u:${rawUser.toLowerCase()}'
          : 'n:${dev.childName.trim().toLowerCase()}';

      if (groups.containsKey(key)) {
        groups[key]!.devices.add(dev);
      } else {
        groups[key] = _ChildAccountGroup(
          childName: dev.childName.trim().isEmpty
              ? 'Bé chưa đặt tên'
              : dev.childName.trim(),
          childUsername: hasUsername ? rawUser : null,
          devices: [dev],
        );
      }
    }

    return groups.values.toList();
  }

  void _showManageChildrenModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.family_restroom_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Quản Lý & Liên Kết Trẻ Em',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Backend KidGuard liên kết tài khoản con qua username có Role "Child" và thiết bị được gán. Tài khoản trẻ cần xác thực email OTP hoặc phân quyền bởi Admin.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade900,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.link_rounded, color: Colors.teal.shade700),
                ),
                title: const Text(
                  'Gán Tài Khoản Trẻ Vào Thiết Bị',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Cập nhật username (@child) cho thiết bị để trẻ đăng nhập Child Dashboard.',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  if (_devices.isEmpty) {
                    _navigateToAddDevice();
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DeviceListScreen(currentUser: widget.user),
                      ),
                    ).then((_) => _loadAllData());
                  }
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person_add_alt_1_rounded,
                    color: Colors.indigo.shade700,
                  ),
                ),
                title: const Text(
                  'Đăng Ký Tài Khoản Cho Trẻ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Tạo tài khoản mới với vai trò Trẻ Em (Role: Child) qua xác thực Email OTP.',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const RegisterScreen(initialRole: 'Child'),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.help_outline_rounded,
                    color: Colors.amber.shade800,
                  ),
                ),
                title: const Text(
                  'Quy Trình & Hướng Dẫn Role Child',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Xem quy định phân quyền Role Child từ Admin hoặc Public Register.',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRoleExplanationDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoleExplanationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Quy Trình Role Child', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '1. Tạo tài khoản Child:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              '• Tự đăng ký: Tại màn hình Đăng ký, chọn Vai trò "Trẻ Em (Child)" và xác thực mã OTP gửi về Email.\n• Phân quyền Admin: Quản trị viên sử dụng API PUT /api/Admin/users/{username}/role để đổi role thành "Child".',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
            SizedBox(height: 10),
            Text(
              '2. Liên kết vào thiết bị:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              '• Phụ huynh nhập đúng @username của trẻ vào trường "Tài khoản của trẻ (Child Username)" trên thiết bị.\n• Backend tự động kiểm tra tài khoản tồn tại và có Role Child hợp lệ.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }

  void _showUnacknowledgedAlertsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.red.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cảnh Báo Tiếng Ồn Vượt Ngưỡng',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_unacknowledgedAlerts.length} sự kiện chưa xác nhận từ thiết bị con',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_unacknowledgedAlerts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline_rounded,
                            color: Colors.green.shade600,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Không có cảnh báo vi phạm nào!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Môi trường âm thanh quanh các thiết bị con đều an toàn.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.45,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _unacknowledgedAlerts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final alert = _unacknowledgedAlerts[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    size: 18,
                                    color: Colors.red.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Mức ồn: ${alert.decibel.toStringAsFixed(1)} dB (Ngưỡng ${alert.thresholdDb.toStringAsFixed(0)} dB)',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.red.shade900,
                                      ),
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: () async {
                                      final ok = await _noiseService
                                          .acknowledgeAlert(alert.id);
                                      if (ok) {
                                        setModalState(() {
                                          _unacknowledgedAlerts.removeWhere(
                                            (a) => a.id == alert.id,
                                          );
                                        });
                                        setState(() {});
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      foregroundColor: Colors.red.shade800,
                                      side: BorderSide(
                                        color: Colors.red.shade300,
                                      ),
                                    ),
                                    child: const Text(
                                      'Xác nhận',
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Thời gian: ${alert.measuredAt.toLocal().toString().split('.')[0]}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openNoiseMonitoring() {
    if (_devices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa có thiết bị con nào được kết nối để theo dõi tiếng ồn.',
          ),
          backgroundColor: AppColors.textSecondary,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Giám Sát Tiếng Ồn Thiết Bị Con',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Chọn thiết bị để xem báo cáo telemetry & quản lý ngưỡng',
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
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: Colors.teal.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Phụ huynh quản lý ngưỡng và theo dõi lịch sử số đo từ máy con. Không sử dụng microphone trên máy phụ huynh.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.teal.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ..._devices.map(
                (dev) => ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade50,
                    child: const Icon(
                      Icons.phone_android_rounded,
                      color: Colors.teal,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '${dev.childName} — ${dev.deviceName}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    'Ngưỡng an toàn áp dụng: ${dev.noiseThresholdDb.toInt()} dB',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeviceDetailScreen(
                          device: dev,
                          currentUser: widget.user,
                        ),
                      ),
                    ).then((_) => _loadAllData());
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lockedCount = _devices.where((d) => d.isLocked).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Bảng Điều Khiển Phụ Huynh',
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.primary,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddDevice,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm Thiết Bị Con'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Profile Card
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
                        backgroundColor: AppColors.primaryLight,
                        child: const Icon(
                          Icons.family_restroom,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.user.fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.user.email,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'ROLE: PARENT (PHỤ HUYNH)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ================= SECTION A: TỔNG QUAN (OVERVIEW) =================
              const Text(
                'Tổng Quan Giám Sát',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _buildOverviewGrid(lockedCount),
              const SizedBox(height: 20),

              // ================= SECTION B: QUẢN LÝ TRẺ EM =================
              Row(
                children: [
                  const Icon(
                    Icons.family_restroom_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Quản Lý Trẻ Em',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  FilledButton.tonalIcon(
                    onPressed: _showManageChildrenModal,
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                    label: const Text(
                      'Thêm / Liên kết',
                      style: TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_devices.isEmpty && !_isLoadingDevices) ...[
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Icon(
                          Icons.child_care_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Chưa có hồ sơ trẻ em',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Thêm thiết bị và liên kết tài khoản con (@child) để quản lý thời gian sử dụng và giám sát an toàn.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _showManageChildrenModal,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Thêm / Liên Kết Trẻ Em'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                for (final group in _groupedChildren)
                  _buildChildAccountCard(group),
                const SizedBox(height: 8),
              ],

              // ================= SECTION C: THEO DÕI & QUẢN LÝ =================
              const Text(
                'Theo Dõi & Quản Lý',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              // Sub-card C0: Tính Năng Sáng Tạo - Góc An Toàn Gia Đình (TASK 05.2)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                ),
                color: Colors.white,
                child: InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FamilySafetyInsightsScreen(
                          currentUser: widget.user,
                        ),
                      ),
                    );
                    _loadAllData();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    Color(0xFF1565C0),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.insights_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 2,
                                    children: [
                                      const Text(
                                        'Góc An Toàn Gia Đình',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade100,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.amber.shade400,
                                          ),
                                        ),
                                        child: Text(
                                          'Sáng Tạo',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'KidGuard Safety Insights',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Xem thống kê và những điều cần chú ý từ thiết bị của con.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: Icon(
                                        Icons.devices_rounded,
                                        size: 13,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                    const WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: SizedBox(width: 5),
                                    ),
                                    TextSpan(
                                      text: '${_devices.length} thiết bị',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_unacknowledgedAlerts.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: Icon(
                                          Icons.warning_amber_rounded,
                                          size: 13,
                                          color: Colors.red.shade700,
                                        ),
                                      ),
                                      const WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: SizedBox(width: 5),
                                      ),
                                      TextSpan(
                                        text:
                                            '${_unacknowledgedAlerts.length} cảnh báo mới',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.red.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green.shade200,
                                  ),
                                ),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 13,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                      const WidgetSpan(
                                        alignment: PlaceholderAlignment.middle,
                                        child: SizedBox(width: 5),
                                      ),
                                      TextSpan(
                                        text: 'Trạng thái an toàn',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FamilySafetyInsightsScreen(
                                    currentUser: widget.user,
                                  ),
                                ),
                              );
                              _loadAllData();
                            },
                            icon: const Icon(Icons.bar_chart_rounded, size: 18),
                            label: const Text(
                              'Khám Phá Góc An Toàn',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Sub-card C1: CRUD Thiết bị con
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.devices_rounded,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Thiết Bị Của Trẻ Em',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DeviceListScreen(
                                    currentUser: widget.user,
                                  ),
                                ),
                              );
                              _loadAllData();
                            },
                            icon: const Icon(Icons.list_alt_rounded, size: 16),
                            label: const Text(
                              'Xem tất cả',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_isLoadingDevices) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ] else if (_devicesError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Lỗi tải thiết bị: $_devicesError',
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: _loadAllData,
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_devices.isEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Column(
                              children: [
                                const Text(
                                  'Chưa có thiết bị nào được kết nối',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                OutlinedButton.icon(
                                  onPressed: _navigateToAddDevice,
                                  icon: const Icon(Icons.add_rounded, size: 16),
                                  label: const Text('Thêm Thiết Bị Ngay'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        ..._devices
                            .take(3)
                            .map((device) => _buildDeviceItem(device)),
                        if (_devices.length > 3)
                          Center(
                            child: TextButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DeviceListScreen(
                                      currentUser: widget.user,
                                    ),
                                  ),
                                );
                                _loadAllData();
                              },
                              child: Text(
                                'Xem thêm ${_devices.length - 3} thiết bị khác...',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Sub-card C2: Giám sát tiếng ồn (Parent Telemetry & Threshold Control)
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.graphic_eq_rounded,
                              color: Colors.teal,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Giám Sát Mức Ồn Môi Trường',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Theo dõi các chỉ số tiếng ồn được gửi từ thiết bị của con và cấu hình ngưỡng an toàn. Phụ huynh không trực tiếp dùng micro để đo.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.teal.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 14,
                              color: Colors.teal.shade800,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Quản lý ngưỡng an toàn • Theo dõi Telemetry lịch sử & cảnh báo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.teal.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _openNoiseMonitoring,
                            icon: const Icon(
                              Icons.analytics_outlined,
                              size: 16,
                            ),
                            label: const Text(
                              'Xem Báo Cáo Theo Thiết Bị',
                              style: TextStyle(fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.teal.shade800,
                              side: BorderSide(color: Colors.teal.shade300),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _showUnacknowledgedAlertsSheet,
                            icon: Icon(
                              Icons.notifications_active_outlined,
                              size: 16,
                              color: _unacknowledgedAlerts.isNotEmpty
                                  ? Colors.red.shade700
                                  : Colors.teal.shade800,
                            ),
                            label: Text(
                              'Cảnh Báo (${_unacknowledgedAlerts.length})',
                              style: TextStyle(
                                fontSize: 12,
                                color: _unacknowledgedAlerts.isNotEmpty
                                    ? Colors.red.shade800
                                    : Colors.teal.shade800,
                                fontWeight: _unacknowledgedAlerts.isNotEmpty
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: _unacknowledgedAlerts.isNotEmpty
                                    ? Colors.red.shade300
                                    : Colors.teal.shade300,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Sub-card C3: Quét QR thiết bị
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: Colors.indigo,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Tra Cứu Thiết Bị Bằng Mã QR',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Quét mã QR trên màn hình ứng dụng Child của con để tra cứu thông tin thiết bị và kiểm tra toàn vẹn dữ liệu (checksum FNV-1a).',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  QrScannerScreen(currentUser: widget.user),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 16,
                        ),
                        label: const Text(
                          'Mở Trình Quét Mã QR',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.indigo.shade800,
                          side: BorderSide(color: Colors.indigo.shade300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ================= SECTION D: BẢO MẬT TÀI KHOẢN =================
              const Text(
                'Bảo Mật Tài Khoản',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.face_rounded,
                              color: Colors.deepPurple,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
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
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Icon(
                                      _hasFace
                                          ? Icons.check_circle_rounded
                                          : Icons.info_outline_rounded,
                                      size: 13,
                                      color: _hasFace
                                          ? Colors.green.shade700
                                          : Colors.amber.shade800,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _hasFace
                                          ? 'Đã đăng ký Face AI'
                                          : 'Chưa đăng ký Face AI',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: _hasFace
                                            ? Colors.green.shade800
                                            : Colors.amber.shade900,
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
                      Text(
                        'Đăng ký mẫu khuôn mặt cho tài khoản phụ huynh (@${widget.user.username}) để đăng nhập sinh trắc học nhanh chóng bằng ArcFace AI.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade50.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.deepPurple.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_person_outlined,
                              size: 14,
                              color: Colors.deepPurple.shade700,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Mẫu khuôn mặt này thuộc về phụ huynh. Ứng dụng không truy cập hoặc can thiệp mẫu khuôn mặt của trẻ em.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.deepPurple.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
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
                              final hasFace = await _faceAuthService
                                  .checkHasFace();
                              if (mounted) setState(() => _hasFace = hasFace);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                            ),
                            icon: const Icon(
                              Icons.camera_alt_outlined,
                              size: 16,
                            ),
                            label: Text(
                              _hasFace
                                  ? 'Cập Nhật Mẫu Khuôn Mặt'
                                  : 'Đăng Ký Khuôn Mặt',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (_hasFace)
                            OutlinedButton.icon(
                              onPressed: _handleDeleteParentFace,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                side: BorderSide(color: Colors.red.shade300),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                              ),
                              icon: const Icon(Icons.delete_outline, size: 16),
                              label: const Text(
                                'Xóa Mẫu',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ================= SECTION DEBUG / DEVELOPMENT =================
              Card(
                elevation: 0,
                color: Colors.grey.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.developer_mode_rounded,
                            size: 18,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Kiểm Thử Phân Quyền Backend Thực Tế (JWT)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Xác minh token thật gửi tới các API backend yêu cầu quyền cụ thể (Dành cho kiểm thử & chấm bài):',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isTesting
                                ? null
                                : () => _testBackendAuthorization(
                                    ApiConstants.childDevices,
                                    '/api/ChildDeviceApi',
                                  ),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 16,
                            ),
                            label: const Text(
                              'Test Devices (Kỳ vọng: 200)',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isTesting
                                ? null
                                : () => _testBackendAuthorization(
                                    ApiConstants.adminOnly,
                                    '/api/Admin/users',
                                  ),
                            icon: const Icon(Icons.block, size: 16),
                            label: const Text(
                              'Test Admin-Only (Kỳ vọng: 403)',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      if (_isTesting) ...[
                        const SizedBox(height: 10),
                        const Center(child: CircularProgressIndicator()),
                      ] else if (_testResult != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade900,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _testResult!,
                            style: const TextStyle(
                              color: Colors.lightGreenAccent,
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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

  Widget _buildOverviewGrid(int lockedCount) {
    final activeCount = _devices.length - lockedCount;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildOverviewStatCard(
                label: 'Thiết bị con',
                value: '${_devices.length}',
                subLabel: '${activeCount >= 0 ? activeCount : 0} hoạt động',
                icon: Icons.devices_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildOverviewStatCard(
                label: 'Đang khóa',
                value: '$lockedCount',
                subLabel: lockedCount > 0 ? 'Cần chú ý' : 'Bình thường',
                icon: Icons.lock_rounded,
                color: lockedCount > 0
                    ? Colors.red.shade700
                    : Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildOverviewStatCard(
                label: 'Hồ sơ trẻ em',
                value: '${_groupedChildren.length}',
                subLabel: 'Đã liên kết',
                icon: Icons.family_restroom_rounded,
                color: Colors.indigo.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: _showUnacknowledgedAlertsSheet,
                borderRadius: BorderRadius.circular(12),
                child: _buildOverviewStatCard(
                  label: 'Cảnh báo ồn',
                  value: '${_unacknowledgedAlerts.length}',
                  subLabel: _unacknowledgedAlerts.isNotEmpty
                      ? 'Nhấn để xem'
                      : 'Bình thường',
                  icon: Icons.warning_amber_rounded,
                  color: _unacknowledgedAlerts.isNotEmpty
                      ? Colors.amber.shade900
                      : Colors.teal.shade700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOverviewStatCard({
    required String label,
    required String value,
    required String subLabel,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subLabel,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildAccountCard(_ChildAccountGroup group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: group.hasLinkedAccount
              ? Colors.teal.shade200
              : Colors.amber.shade300,
          width: 1,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: group.hasLinkedAccount
                      ? Colors.teal.shade50
                      : Colors.amber.shade50,
                  child: Text(
                    group.childName.isNotEmpty
                        ? group.childName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: group.hasLinkedAccount
                          ? Colors.teal.shade800
                          : Colors.amber.shade900,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.childName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (group.hasLinkedAccount)
                        Row(
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 13,
                              color: Colors.teal.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '@${group.childUsername}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.teal.shade700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.teal.shade200,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                'Role: Child',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal.shade800,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 13,
                              color: Colors.amber.shade800,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Chưa liên kết tài khoản con',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.amber.shade900,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.edit_note_rounded,
                    color: AppColors.primary,
                  ),
                  tooltip: 'Gán / Sửa thông tin tài khoản trẻ',
                  onPressed: () async {
                    if (group.devices.isNotEmpty) {
                      final res = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeviceFormScreen(
                            device: group.devices.first,
                            defaultParentUsername: widget.user.username,
                          ),
                        ),
                      );
                      if (res == true) _loadAllData();
                    }
                  },
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Thiết bị được gán (${group.devices.length}):',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DeviceListScreen(currentUser: widget.user),
                      ),
                    );
                    _loadAllData();
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'Xem CRUD thiết bị',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: group.devices.map((dev) {
                return InkWell(
                  onTap: () async {
                    final res = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DeviceDetailScreen(
                          device: dev,
                          currentUser: widget.user,
                        ),
                      ),
                    );
                    if (res == true) _loadAllData();
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: dev.isLocked
                          ? Colors.red.shade50
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: dev.isLocked
                            ? Colors.red.shade200
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          dev.isLocked
                              ? Icons.lock_rounded
                              : Icons.smartphone_rounded,
                          size: 14,
                          color: dev.isLocked
                              ? Colors.red.shade700
                              : AppColors.textPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dev.deviceName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: dev.isLocked
                                ? Colors.red.shade800
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (dev.isLocked) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Khóa',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceItem(ChildDeviceModel device) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: device.isLocked
              ? Colors.red.shade50
              : AppColors.primaryLight,
          child: Icon(
            device.isLocked ? Icons.lock_rounded : Icons.phone_android_rounded,
            color: device.isLocked ? Colors.red.shade700 : AppColors.primary,
            size: 18,
          ),
        ),
        title: Text(
          device.childName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          '${device.deviceName} • Giới hạn: ${device.formattedScreenTime} • Ngưỡng: ${device.noiseThresholdDb.toInt()} dB',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: device.isLocked ? Colors.red.shade50 : Colors.green.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            device.isLocked ? 'Đang khóa' : 'Hoạt động',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: device.isLocked
                  ? Colors.red.shade700
                  : Colors.green.shade700,
            ),
          ),
        ),
        onTap: () async {
          final res = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  DeviceDetailScreen(device: device, currentUser: widget.user),
            ),
          );
          if (res == true) _loadAllData();
        },
      ),
    );
  }
}

class _ChildAccountGroup {
  final String childName;
  final String? childUsername;
  final List<ChildDeviceModel> devices;

  _ChildAccountGroup({
    required this.childName,
    this.childUsername,
    required this.devices,
  });

  bool get hasLinkedAccount =>
      childUsername != null && childUsername!.trim().isNotEmpty;
}
