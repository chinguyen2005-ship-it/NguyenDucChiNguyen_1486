import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/device_model.dart';
import '../../services/device_service.dart';
import '../../widgets/custom_button.dart';

class DeviceFormScreen extends StatefulWidget {
  final ChildDeviceModel? device;
  final String? defaultParentUsername;

  const DeviceFormScreen({super.key, this.device, this.defaultParentUsername});

  bool get isEditing => device != null;

  @override
  State<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends State<DeviceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _deviceService = DeviceService();

  late TextEditingController _childNameController;
  late TextEditingController _deviceNameController;
  late TextEditingController _customAppController;
  late TextEditingController _childUsernameController;

  int _screenTimeMinutes = 120;
  bool _isLocked = false;
  double _noiseThresholdDb = 80.0;
  final Set<String> _selectedBlockedApps = {};

  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _commonApps = [
    'TikTok',
    'YouTube',
    'Roblox',
    'FreeFire',
    'Facebook',
    'Instagram',
  ];

  final List<int> _timePresets = [60, 90, 120, 180, 240];

  @override
  void initState() {
    super.initState();
    final d = widget.device;
    _childNameController = TextEditingController(text: d?.childName ?? '');
    _deviceNameController = TextEditingController(text: d?.deviceName ?? '');
    _customAppController = TextEditingController();
    _childUsernameController = TextEditingController(
      text: d?.childUsername ?? '',
    );

    if (d != null) {
      _screenTimeMinutes = d.screenTimeLimitMinutes;
      _isLocked = d.isLocked;
      _noiseThresholdDb = d.noiseThresholdDb;
      if (d.blockedApps != null && d.blockedApps!.trim().isNotEmpty) {
        _selectedBlockedApps.addAll(d.blockedAppList);
      }
    }
  }

  @override
  void dispose() {
    _childNameController.dispose();
    _deviceNameController.dispose();
    _customAppController.dispose();
    _childUsernameController.dispose();
    super.dispose();
  }

  void _addCustomApp() {
    final app = _customAppController.text.trim();
    if (app.isNotEmpty) {
      setState(() {
        _selectedBlockedApps.add(app);
        _customAppController.clear();
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final blockedAppsStr = _selectedBlockedApps.isNotEmpty
        ? _selectedBlockedApps.join(', ')
        : null;

    final dto = ChildDeviceUpsertDto(
      id: widget.device?.id,
      childName: _childNameController.text.trim(),
      deviceName: _deviceNameController.text.trim(),
      screenTimeLimitMinutes: _screenTimeMinutes,
      blockedApps: blockedAppsStr,
      isLocked: _isLocked,
      latitude: widget.device?.latitude ?? 10.8018,
      longitude: widget.device?.longitude ?? 106.7144,
      parentUsername:
          widget.device?.parentUsername ?? widget.defaultParentUsername,
      childUsername: _childUsernameController.text.trim().isNotEmpty
          ? _childUsernameController.text.trim()
          : null,
      noiseThresholdDb: _noiseThresholdDb,
    );

    ApiResponse response;
    if (widget.isEditing) {
      response = await _deviceService.updateDevice(widget.device!.id, dto);
    } else {
      response = await _deviceService.addDevice(dto);
    }

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Cập nhật thiết bị thành công!'
                : 'Thêm thiết bị mới thành công!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      setState(() {
        _errorMessage = response.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing
        ? 'Chỉnh Sửa Thiết Bị'
        : 'Thêm Thiết Bị Của Trẻ';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Section 1: Thông tin cơ bản
                _buildSectionHeader(Icons.person_rounded, 'Thông Tin Cơ Bản'),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _childNameController,
                  decoration: InputDecoration(
                    labelText: 'Tên của trẻ *',
                    hintText: 'VD: Bé Minh An, Bé Bảo Ngọc',
                    prefixIcon: const Icon(
                      Icons.face_rounded,
                      color: AppColors.primary,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập tên của trẻ';
                    }
                    if (val.trim().length > 100) {
                      return 'Tên không được quá 100 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _deviceNameController,
                  decoration: InputDecoration(
                    labelText: 'Tên thiết bị *',
                    hintText: 'VD: iPhone 13 Mini, iPad Air, Galaxy A14',
                    prefixIcon: const Icon(
                      Icons.phone_android_rounded,
                      color: AppColors.primary,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Vui lòng nhập tên thiết bị';
                    }
                    if (val.trim().length > 100) {
                      return 'Tên thiết bị không được quá 100 ký tự';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _childUsernameController,
                  decoration: InputDecoration(
                    labelText: 'Tài khoản của trẻ (Tùy chọn)',
                    hintText: 'Tên đăng nhập nếu trẻ dùng app KidGuard',
                    prefixIcon: const Icon(
                      Icons.account_circle_outlined,
                      color: AppColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Section 2: Quản lý thời gian sử dụng
                _buildSectionHeader(Icons.timer_rounded, 'Thời Gian Sử Dụng'),
                const SizedBox(height: 12),

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
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            const Text(
                              'Giới hạn mỗi ngày:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_screenTimeMinutes ~/ 60}h ${_screenTimeMinutes % 60}m ($_screenTimeMinutes phút)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Slider(
                          value: _screenTimeMinutes.toDouble(),
                          min: 0,
                          max: 360,
                          divisions: 24, // 15-minute steps
                          label: '$_screenTimeMinutes phút',
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() {
                              _screenTimeMinutes = val.toInt();
                            });
                          },
                        ),
                        Wrap(
                          spacing: 8,
                          children: _timePresets.map((mins) {
                            final isSelected = _screenTimeMinutes == mins;
                            return ChoiceChip(
                              label: Text(
                                '${mins ~/ 60}h${mins % 60 > 0 ? " ${mins % 60}m" : ""}',
                              ),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              onSelected: (_) {
                                setState(() {
                                  _screenTimeMinutes = mins;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Section 3: Ứng dụng bị chặn
                _buildSectionHeader(Icons.block_rounded, 'Chặn Ứng Dụng'),
                const SizedBox(height: 12),

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
                        const Text(
                          'Chọn ứng dụng muốn hạn chế:',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _commonApps.map((app) {
                            final isBlocked = _selectedBlockedApps.contains(
                              app,
                            );
                            return FilterChip(
                              label: Text(app),
                              selected: isBlocked,
                              selectedColor: Colors.red.shade100,
                              checkmarkColor: Colors.red.shade700,
                              labelStyle: TextStyle(
                                color: isBlocked
                                    ? Colors.red.shade800
                                    : AppColors.textPrimary,
                                fontWeight: isBlocked
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedBlockedApps.add(app);
                                  } else {
                                    _selectedBlockedApps.remove(app);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customAppController,
                                decoration: InputDecoration(
                                  hintText:
                                      'Thêm app khác (VD: Zalo, Netflix)...',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onSubmitted: (_) => _addCustomApp(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _addCustomApp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                              child: const Text('Thêm'),
                            ),
                          ],
                        ),
                        if (_selectedBlockedApps.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 6),
                          Text(
                            'Đang chặn (${_selectedBlockedApps.length}): ${_selectedBlockedApps.join(", ")}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Section 4: Khóa máy & Ngưỡng tiếng ồn
                _buildSectionHeader(
                  Icons.security_rounded,
                  'Bảo Vệ & Cảnh Báo',
                ),
                const SizedBox(height: 12),

                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        value: _isLocked,
                        activeThumbColor: Colors.red.shade700,
                        title: const Text(
                          'Khóa Thiết Bị Từ Xa',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          _isLocked
                              ? 'Thiết bị đang bị khóa'
                              : 'Thiết bị hoạt động bình thường',
                          style: TextStyle(
                            color: _isLocked
                                ? Colors.red.shade700
                                : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _isLocked = val;
                          });
                        },
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                const Text(
                                  'Ngưỡng cảnh báo tiếng ồn:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${_noiseThresholdDb.toInt()} dB',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _noiseThresholdDb,
                              min: 40,
                              max: 120,
                              divisions: 16,
                              label: '${_noiseThresholdDb.toInt()} dB',
                              activeColor: Colors.orange,
                              onChanged: (val) {
                                setState(() {
                                  _noiseThresholdDb = val;
                                });
                              },
                            ),
                            const Text(
                              'Khi micro điện thoại trẻ đo âm thanh >= ngưỡng này, hệ thống sẽ gửi email cảnh báo tới phụ huynh.',
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
                ),
                const SizedBox(height: 32),

                // Submit Button
                CustomButton(
                  text: widget.isEditing ? 'Lưu Thay Đổi' : 'Thêm Thiết Bị Mới',
                  isLoading: _isLoading,
                  icon: widget.isEditing
                      ? Icons.save_rounded
                      : Icons.add_circle_outline_rounded,
                  onPressed: _handleSubmit,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
