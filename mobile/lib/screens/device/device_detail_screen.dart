import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/auth_models.dart';
import '../../models/device_model.dart';
import '../../models/noise_model.dart';
import '../../services/device_service.dart';
import '../../services/noise_service.dart';
import '../noise/noise_meter_screen.dart';
import '../qr/qr_generator_screen.dart';
import 'device_form_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  final ChildDeviceModel device;
  final UserProfile currentUser;

  const DeviceDetailScreen({
    super.key,
    required this.device,
    required this.currentUser,
  });

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  final _deviceService = DeviceService();
  final _noiseService = NoiseService();
  late ChildDeviceModel _device;
  bool _isLoading = false;
  bool _isTogglingLock = false;

  NoiseHistoryModel? _noiseHistory;
  bool _isLoadingNoise = false;

  @override
  void initState() {
    super.initState();
    _device = widget.device;
    _loadNoiseHistory();
  }

  Future<void> _refreshDevice() async {
    setState(() => _isLoading = true);
    final res = await _deviceService.getDeviceById(_device.id);
    await _loadNoiseHistory();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.success && res.data != null) {
        _device = res.data!;
      }
    });
  }

  Future<void> _loadNoiseHistory() async {
    setState(() => _isLoadingNoise = true);
    final history = await _noiseService.getNoiseHistory(_device.id, take: 10);
    if (!mounted) return;
    setState(() {
      _noiseHistory = history;
      _isLoadingNoise = false;
    });
  }

  Widget _buildThresholdChip(
    String label,
    double value,
    double currentValue,
    void Function(double) onSelected,
  ) {
    final isSelected = (value - currentValue).abs() < 1;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      selectedColor: AppColors.primaryLight,
      onSelected: (_) => onSelected(value),
    );
  }

  Future<void> _showUpdateThresholdDialog() async {
    if (!widget.currentUser.isAdmin && !widget.currentUser.isParent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chỉ Phụ huynh mới có quyền cài đặt ngưỡng cảnh báo.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    double tempThreshold = _device.noiseThresholdDb;
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.tune_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Flexible(child: Text('Cài Đặt Ngưỡng Tiếng Ồn')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Khi mức âm thanh trên máy của trẻ vượt ngưỡng này, server sẽ tự động tạo cảnh báo và gửi email cho phụ huynh.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  '${tempThreshold.toInt()} dB',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Slider(
                value: tempThreshold.clamp(40.0, 120.0),
                min: 40,
                max: 120,
                divisions: 16,
                label: '${tempThreshold.toInt()} dB',
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setDialogState(() => tempThreshold = val);
                },
              ),
              const SizedBox(height: 6),
              const Text(
                'Mức khuyến nghị:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildThresholdChip(
                    '60 dB (Yên tĩnh)',
                    60,
                    tempThreshold,
                    (val) => setDialogState(() => tempThreshold = val),
                  ),
                  _buildThresholdChip(
                    '75 dB (Tiêu chuẩn)',
                    75,
                    tempThreshold,
                    (val) => setDialogState(() => tempThreshold = val),
                  ),
                  _buildThresholdChip(
                    '85 dB (Giờ chơi)',
                    85,
                    tempThreshold,
                    (val) => setDialogState(() => tempThreshold = val),
                  ),
                  _buildThresholdChip(
                    '95 dB (Báo động)',
                    95,
                    tempThreshold,
                    (val) => setDialogState(() => tempThreshold = val),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, tempThreshold),
              child: const Text('Lưu Ngưỡng'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result == _device.noiseThresholdDb) return;

    setState(() => _isLoading = true);
    final res = await _noiseService.updateNoiseThreshold(_device.id, result);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      setState(() {
        _device = _device.copyWith(noiseThresholdDb: res.thresholdDb ?? result);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppColors.success,
        ),
      );
      _loadNoiseHistory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleAcknowledgeAlert(int eventId) async {
    final success = await _noiseService.acknowledgeAlert(eventId);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xác nhận xem cảnh báo tiếng ồn.'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadNoiseHistory();
    }
  }

  void _showRemoteBlockedExplanationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Colors.orange, size: 26),
            SizedBox(width: 8),
            Flexible(child: Text('Trạng Thái: Yêu Cầu Đo Từ Xa')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFFFFE0B2),
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
              child: const Text(
                'REMOTE REQUEST: BLOCKED',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFFE65100),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '1. Kiến trúc Backend:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'Backend nhóm 13 hiện tại chưa hỗ trợ giao thức truyền lệnh thời gian thực hai chiều (FCM Push Notification hoặc SignalR Hub). Không có hàng đợi lệnh từ xa trong cơ sở dữ liệu.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '2. Nguyên tắc An toàn & Quyền riêng tư:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'KidGuard tuân thủ bảo vệ trẻ em: Tuyệt đối KHÔNG tự động bật microphone bí mật, KHÔNG ghi âm hoặc nghe lén ngầm khi trẻ không chủ động cấp quyền.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '3. Phương án thực hiện:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            SizedBox(height: 4),
            Text(
              'Phụ huynh có thể cấu hình Ngưỡng cảnh báo và xem Lịch sử viễn thông tại đây. Trẻ sẽ chủ động mở máy đo khi cần kiểm tra độ ồn học tập.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
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

  Future<void> _handleToggleLock() async {
    final newLockState = !_device.isLocked;
    setState(() => _isTogglingLock = true);

    final res = await _deviceService.toggleLock(_device, newLockState);

    if (!mounted) return;
    setState(() => _isTogglingLock = false);

    if (res.success) {
      setState(() {
        _device = _device.copyWith(isLocked: newLockState);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newLockState
                ? 'Đã KHÓA thiết bị ${_device.deviceName} từ xa!'
                : 'Đã MỞ KHÓA thiết bị ${_device.deviceName}!',
          ),
          backgroundColor: newLockState
              ? Colors.red.shade700
              : AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 8),
            Flexible(child: Text('Xác Nhận Xóa Thiết Bị')),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa thiết bị "${_device.deviceName}" của "${_device.childName}"?\n\n'
          'Toàn bộ lịch sử cảnh báo và thiết lập sẽ bị xóa vĩnh viễn khỏi hệ thống.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa Vĩnh Viễn'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    final res = await _deviceService.deleteDevice(_device.id);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa thiết bị "${_device.deviceName}" thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true); // Return true indicating item was deleted
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _navigateToEdit() async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceFormScreen(
          device: _device,
          defaultParentUsername: widget.currentUser.username,
        ),
      ),
    );

    if (updated == true) {
      _refreshDevice();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = widget.currentUser.isAdmin || widget.currentUser.isParent;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_device.childName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _refreshDevice,
          ),
          if (canManage) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              tooltip: 'Chỉnh sửa',
              onPressed: _navigateToEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Xóa thiết bị',
              onPressed: _handleDelete,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshDevice,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main Header Card
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
                              child: Icon(
                                _device.isLocked
                                    ? Icons.lock_rounded
                                    : Icons.phone_android_rounded,
                                size: 40,
                                color: _device.isLocked
                                    ? Colors.red.shade700
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _device.childName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _device.deviceName,
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _device.isLocked
                                    ? Colors.red.shade50
                                    : Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _device.isLocked
                                      ? Colors.red.shade300
                                      : Colors.green.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _device.isLocked
                                        ? Icons.lock_outline
                                        : Icons.check_circle_outline,
                                    size: 16,
                                    color: _device.isLocked
                                        ? Colors.red.shade700
                                        : Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _device.isLocked
                                          ? 'THIẾT BỊ ĐANG KHÓA'
                                          : 'HOẠT ĐỘNG BÌNH THƯỜNG',
                                      style: TextStyle(
                                        color: _device.isLocked
                                            ? Colors.red.shade700
                                            : Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
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

                    // Quick Lock / Unlock Toggle Action (Parent only)
                    if (canManage) ...[
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Icon(
                            _device.isLocked
                                ? Icons.lock_open_rounded
                                : Icons.lock_rounded,
                            color: _device.isLocked
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            size: 28,
                          ),
                          title: Text(
                            _device.isLocked
                                ? 'Mở Khóa Thiết Bị'
                                : 'Khóa Thiết Bị Từ Xa',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            _device.isLocked
                                ? 'Cho phép trẻ tiếp tục dùng máy'
                                : 'Khóa tức thì màn hình điện thoại',
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: _isTogglingLock
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _device.isLocked
                                        ? Colors.green.shade600
                                        : Colors.red.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                  ),
                                  onPressed: _handleToggleLock,
                                  child: Text(
                                    _device.isLocked ? 'Mở khóa' : 'Khóa máy',
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Info Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            icon: Icons.timer_rounded,
                            iconColor: Colors.blue.shade700,
                            title: 'Thời Gian Dùng',
                            value: _device.formattedScreenTime,
                            subtitle: 'Tối đa mỗi ngày',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            icon: Icons.graphic_eq_rounded,
                            iconColor: Colors.orange.shade700,
                            title: 'Ngưỡng Tiếng Ồn',
                            value: '${_device.noiseThresholdDb.toInt()} dB',
                            subtitle: _device.lastNoiseDb != null
                                ? 'Đo gần nhất: ${_device.lastNoiseDb!.toInt()} dB'
                                : 'Chưa có dữ liệu đo',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Blocked Apps Section
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.block_rounded,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Ứng Dụng Đang Bị Chặn',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _device.blockedAppList.isEmpty
                                ? const Text(
                                    'Không có ứng dụng nào bị chặn.',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                    ),
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: _device.blockedAppList.map((app) {
                                      return Chip(
                                        avatar: const Icon(
                                          Icons.cancel_rounded,
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                        label: Text(app),
                                        backgroundColor: Colors.red.shade50,
                                        labelStyle: TextStyle(
                                          color: Colors.red.shade800,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location Info
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.teal,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Vị Trí GPS Thiết Bị',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tọa độ: ${_device.latitude.toStringAsFixed(4)}, ${_device.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cập nhật: ${_device.lastUpdated.toLocal().toString().split(".")[0]}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ================= SECTION: PARENT-CONTROLLED NOISE CHECK =================
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
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.graphic_eq_rounded,
                                    color: Colors.teal,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Giám Sát Tiếng Ồn (Parent-Controlled)',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'Kiểm soát ngưỡng an toàn & lịch sử đo của con',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 20,
                                  ),
                                  tooltip: 'Làm mới lịch sử',
                                  onPressed: _loadNoiseHistory,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Ngưỡng cảnh báo hiện tại & Nút chỉnh sửa của Parent
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Ngưỡng cảnh báo áp dụng:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Wrap(
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          spacing: 6,
                                          runSpacing: 2,
                                          children: [
                                            Text(
                                              '${_device.noiseThresholdDb.toInt()} dB',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange.shade800,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: canManage
                                                    ? Colors.blue.shade50
                                                    : Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                canManage
                                                    ? 'Phụ huynh'
                                                    : 'Chỉ xem',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: canManage
                                                      ? Colors.blue.shade800
                                                      : Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (canManage) ...[
                                    const SizedBox(width: 8),
                                    FilledButton.tonalIcon(
                                      onPressed: _showUpdateThresholdDialog,
                                      style: FilledButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                      ),
                                      icon: const Icon(
                                        Icons.tune_rounded,
                                        size: 14,
                                      ),
                                      label: const Text(
                                        'Đổi',
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Remote Request Status Card (MANDATORY REQUIREMENT)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.amber.shade300,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade200,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: const Text(
                                            'REMOTE REQUEST: BLOCKED',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.info_outline_rounded,
                                          size: 18,
                                          color: Colors.orange,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Xem lý do kỹ thuật',
                                        onPressed:
                                            _showRemoteBlockedExplanationDialog,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Backend chưa có kênh truyền lệnh thời gian thực (FCM/SignalR) tới máy của con. Để bảo vệ quyền riêng tư, KidGuard tuyệt đối KHÔNG kích hoạt micro bí mật hay nghe lén.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.black87,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          _showRemoteBlockedExplanationDialog,
                                      icon: const Icon(
                                        Icons.block_rounded,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      label: const Text(
                                        'Yêu Cầu Đo Từ Xa (Chưa khả dụng)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: Colors.grey.shade400,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Thống kê lịch sử viễn thông (Telemetry Stats)
                            if (_isLoadingNoise)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_noiseHistory != null) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildNoiseStatItem(
                                      'Tổng số đo',
                                      '${_noiseHistory!.count}',
                                      Colors.blue.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildNoiseStatItem(
                                      'Cảnh báo',
                                      '${_noiseHistory!.alertCount}',
                                      _noiseHistory!.alertCount > 0
                                          ? Colors.red.shade700
                                          : Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildNoiseStatItem(
                                      'Trung bình',
                                      _noiseHistory!.averageDb != null
                                          ? '${_noiseHistory!.averageDb!.toStringAsFixed(0)} dB'
                                          : '--',
                                      Colors.teal.shade700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildNoiseStatItem(
                                      'Đỉnh cao',
                                      _noiseHistory!.maxDb != null
                                          ? '${_noiseHistory!.maxDb!.toStringAsFixed(0)} dB'
                                          : '--',
                                      Colors.purple.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Lịch sử đo gần nhất
                              if (_noiseHistory!.events.isNotEmpty) ...[
                                const Text(
                                  'Lịch sử đo gần nhất:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                ..._noiseHistory!.events.take(3).map((e) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: e.isAlert
                                          ? Colors.red.shade50
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: e.isAlert
                                            ? Colors.red.shade200
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          e.isAlert
                                              ? Icons.warning_amber_rounded
                                              : Icons.graphic_eq_rounded,
                                          size: 16,
                                          color: e.isAlert
                                              ? Colors.red.shade700
                                              : Colors.teal.shade700,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${e.decibel.toStringAsFixed(1)} dB (Ngưỡng ${e.thresholdDb.toInt()} dB)',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: e.isAlert
                                                      ? Colors.red.shade800
                                                      : AppColors.textPrimary,
                                                ),
                                              ),
                                              Text(
                                                e.measuredAt
                                                    .toLocal()
                                                    .toString()
                                                    .split('.')[0],
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (e.isAlert) ...[
                                          if (!e.isAcknowledged && canManage)
                                            TextButton(
                                              onPressed: () =>
                                                  _handleAcknowledgeAlert(e.id),
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                    ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                              child: const Text(
                                                'Xác nhận đã xem',
                                                style: TextStyle(fontSize: 11),
                                              ),
                                            )
                                          else
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.red.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                e.isAcknowledged
                                                    ? 'ĐÃ XEM'
                                                    : 'CẢNH BÁO',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red.shade800,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  );
                                }),
                              ] else ...[
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'Chưa có dữ liệu đo nào được ghi nhận cho thiết bị này.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],

                            const SizedBox(height: 12),
                            if (canManage) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.teal.shade50.withValues(
                                    alpha: 0.6,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.teal.shade200,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.shield_outlined,
                                      size: 18,
                                      color: Colors.teal.shade800,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Nguyên Tắc Giám Sát Phụ Huynh',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: Colors.teal.shade900,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Phụ huynh theo dõi dữ liệu do máy con gửi lên và quản lý ngưỡng. Ứng dụng không kích hoạt microphone trên máy phụ huynh.',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.teal.shade800,
                                              height: 1.35,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => NoiseMeterScreen(
                                          device: _device,
                                          isParentViewer: false,
                                        ),
                                      ),
                                    );
                                    _refreshDevice();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.shade700,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.play_circle_outline_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Bắt Đầu Đo Tiếng Ồn',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // QR Code Card
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.qr_code_2_rounded,
                            color: Colors.indigo,
                          ),
                        ),
                        title: const Text(
                          'Mã QR Định Danh Thiết Bị',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: const Text(
                          'Tạo mã QR an toàn để tra cứu hoặc kiểm tra thông số thiết bị.',
                          style: TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QrGeneratorScreen(
                                device: _device,
                                currentUser: widget.currentUser,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Action Buttons for Parent/Admin
                    if (canManage) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _navigateToEdit,
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text('Chỉnh Sửa'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _handleDelete,
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                              label: const Text('Xóa Thiết Bị'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: const BorderSide(color: AppColors.error),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoiseStatItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
