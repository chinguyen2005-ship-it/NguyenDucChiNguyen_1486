import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/auth_models.dart';
import '../../models/device_model.dart';
import '../../services/device_service.dart';
import 'device_detail_screen.dart';
import 'device_form_screen.dart';

class DeviceListScreen extends StatefulWidget {
  final UserProfile currentUser;

  const DeviceListScreen({super.key, required this.currentUser});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final _deviceService = DeviceService();
  final _searchController = TextEditingController();

  List<ChildDeviceModel> _devices = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDevices({String? query}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _deviceService.getDevices(
      search: query ?? _searchController.text,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.success) {
        _devices = res.data ?? [];
      } else {
        _errorMessage = res.message;
      }
    });
  }

  Future<void> _navigateToAddDevice() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DeviceFormScreen(
          defaultParentUsername: widget.currentUser.username,
        ),
      ),
    );

    if (added == true) {
      _loadDevices();
    }
  }

  Future<void> _navigateToDetail(ChildDeviceModel device) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DeviceDetailScreen(device: device, currentUser: widget.currentUser),
      ),
    );

    // Refresh if edited or deleted
    if (result == true) {
      _loadDevices();
    }
  }

  Future<void> _handleDeleteDevice(ChildDeviceModel device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
            SizedBox(width: 8),
            Flexible(child: Text('Xác Nhận Xóa')),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa thiết bị "${device.deviceName}" của "${device.childName}"?\n\nDữ liệu sẽ bị xóa vĩnh viễn khỏi SQL Server.',
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
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final res = await _deviceService.deleteDevice(device.id);

    if (!mounted) return;

    if (res.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xóa thiết bị "${device.deviceName}" thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadDevices();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = widget.currentUser.isAdmin || widget.currentUser.isParent;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản Lý Thiết Bị Trẻ Em'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: () => _loadDevices(),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: _navigateToAddDevice,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm Thiết Bị'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm theo tên trẻ hoặc tên máy...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            _loadDevices(query: '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                onSubmitted: (query) => _loadDevices(query: query),
              ),
            ),

            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadDevices(),
                child: _buildContent(canManage),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool canManage) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: AppColors.error,
              ),
              const SizedBox(height: 14),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _loadDevices(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_devices.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.15),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.devices_other_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Chưa Có Thiết Bị Nào',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Thêm thiết bị điện thoại hoặc máy tính bảng của con để bắt đầu giám sát và bảo vệ.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (canManage) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _navigateToAddDevice,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Thêm Thiết Bị Đầu Tiên'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return _buildDeviceCard(device, canManage);
      },
    );
  }

  Widget _buildDeviceCard(ChildDeviceModel device, bool canManage) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _navigateToDetail(device),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Avatar, Info, and Status Badge
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: device.isLocked
                        ? Colors.red.shade50
                        : AppColors.primaryLight,
                    child: Icon(
                      device.isLocked
                          ? Icons.lock_rounded
                          : Icons.phone_android_rounded,
                      color: device.isLocked
                          ? Colors.red.shade700
                          : AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.childName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          device.deviceName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: device.isLocked
                          ? Colors.red.shade50
                          : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: device.isLocked
                            ? Colors.red.shade200
                            : Colors.green.shade200,
                      ),
                    ),
                    child: Text(
                      device.isLocked ? 'Đang khóa' : 'Hoạt động',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: device.isLocked
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Badges info
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Thời lượng: ${device.formattedScreenTime}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.graphic_eq,
                        size: 16,
                        color: Colors.orange.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ngưỡng ồn: ${device.noiseThresholdDb.toInt()} dB',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (device.blockedAppList.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: device.blockedAppList.take(3).map((app) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Chặn: $app',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Manage Action Buttons
              if (canManage) ...[
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        foregroundColor: AppColors.primary,
                      ),
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                      label: const Text(
                        'Chi tiết',
                        style: TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _navigateToDetail(device),
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        foregroundColor: Colors.orange.shade800,
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Sửa', style: TextStyle(fontSize: 12)),
                      onPressed: () async {
                        final updated = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DeviceFormScreen(
                              device: device,
                              defaultParentUsername:
                                  widget.currentUser.username,
                            ),
                          ),
                        );
                        if (updated == true) _loadDevices();
                      },
                    ),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        foregroundColor: AppColors.error,
                      ),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Xóa', style: TextStyle(fontSize: 12)),
                      onPressed: () => _handleDeleteDevice(device),
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
}
