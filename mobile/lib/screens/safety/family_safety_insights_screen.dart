import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/auth_models.dart';
import '../../models/device_model.dart';
import '../../models/noise_model.dart';
import '../../services/device_service.dart';
import '../../services/noise_service.dart';

enum TimeRangeFilter { sevenDays, thirtyDays, all }

class FamilySafetyInsightsScreen extends StatefulWidget {
  final UserProfile currentUser;
  final DeviceService? deviceService;
  final NoiseService? noiseService;

  const FamilySafetyInsightsScreen({
    super.key,
    required this.currentUser,
    this.deviceService,
    this.noiseService,
  });

  @override
  State<FamilySafetyInsightsScreen> createState() =>
      _FamilySafetyInsightsScreenState();
}

class _FamilySafetyInsightsScreenState
    extends State<FamilySafetyInsightsScreen> {
  late final DeviceService _deviceService;
  late final NoiseService _noiseService;

  List<ChildDeviceModel> _devices = [];
  Map<int, NoiseHistoryModel> _histories = {};
  List<NoiseEventModel> _unacknowledgedAlerts = [];

  bool _isLoading = false;
  String? _errorMessage;

  int? _selectedDeviceId; // null = Tất cả thiết bị
  TimeRangeFilter _selectedTimeRange = TimeRangeFilter.sevenDays;

  @override
  void initState() {
    super.initState();
    _deviceService = widget.deviceService ?? DeviceService();
    _noiseService = widget.noiseService ?? NoiseService();

    if (widget.currentUser.isParent) {
      _loadAllInsightsData();
    }
  }

  Future<void> _loadAllInsightsData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final devicesRes = await _deviceService.getDevices();
      if (!devicesRes.success || devicesRes.data == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = devicesRes.message;
        });
        return;
      }

      final devices = devicesRes.data!;
      final alerts = await _noiseService.getUnacknowledgedAlerts(take: 100);

      final Map<int, NoiseHistoryModel> histories = {};
      final fromDate = _getFromDate();

      for (final dev in devices) {
        final history = await _noiseService.getNoiseHistory(
          dev.id,
          from: fromDate,
          take: 100,
        );
        if (history != null) {
          histories[dev.id] = history;
        }
      }

      if (!mounted) return;
      setState(() {
        _devices = devices;
        _histories = histories;
        _unacknowledgedAlerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Không thể tải thông tin chi tiết: $e';
      });
    }
  }

  DateTime? _getFromDate() {
    final now = DateTime.now();
    switch (_selectedTimeRange) {
      case TimeRangeFilter.sevenDays:
        return now.subtract(const Duration(days: 7));
      case TimeRangeFilter.thirtyDays:
        return now.subtract(const Duration(days: 30));
      case TimeRangeFilter.all:
        return null;
    }
  }

  Future<void> _handleAcknowledgeAlert(int alertId) async {
    final ok = await _noiseService.acknowledgeAlert(alertId);
    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xác nhận xem cảnh báo an toàn.'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
      setState(() {
        _unacknowledgedAlerts.removeWhere((a) => a.id == alertId);
        // Cập nhật trạng thái trong histories
        _histories.forEach((devId, history) {
          final updatedEvents = history.events.map((e) {
            if (e.id == alertId) {
              return e.copyWith(isAcknowledged: true);
            }
            return e;
          }).toList();
          _histories[devId] = NoiseHistoryModel(
            deviceId: history.deviceId,
            childName: history.childName,
            noiseThresholdDb: history.noiseThresholdDb,
            lastNoiseDb: history.lastNoiseDb,
            lastNoiseAt: history.lastNoiseAt,
            count: history.count,
            alertCount: history.alertCount,
            averageDb: history.averageDb,
            maxDb: history.maxDb,
            events: updatedEvents,
          );
        });
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Xác nhận cảnh báo thất bại. Vui lòng thử lại.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  List<ChildDeviceModel> get _filteredDevices {
    if (_selectedDeviceId == null) {
      return _devices;
    }
    return _devices.where((d) => d.id == _selectedDeviceId).toList();
  }

  List<NoiseEventModel> get _allFilteredAlerts {
    final fromDate = _getFromDate();
    final Map<int, NoiseEventModel> alertMap = {};

    // 1. Thêm từ các bản ghi lịch sử của thiết bị được lọc
    for (final dev in _filteredDevices) {
      final history = _histories[dev.id];
      if (history != null) {
        for (final e in history.events) {
          if (e.isAlert) {
            if (fromDate == null || e.measuredAt.isAfter(fromDate)) {
              alertMap[e.id] = e.copyWith(
                childName: dev.childName,
                deviceName: dev.deviceName,
              );
            }
          }
        }
      }
    }

    // 2. Thêm từ unacknowledged alerts (nếu thuộc thiết bị được lọc)
    for (final a in _unacknowledgedAlerts) {
      if (_selectedDeviceId == null || a.childDeviceId == _selectedDeviceId) {
        if (fromDate == null || a.measuredAt.isAfter(fromDate)) {
          if (!alertMap.containsKey(a.id)) {
            final matchedDev = _devices.firstWhere(
              (d) => d.id == a.childDeviceId,
              orElse: () => ChildDeviceModel(
                id: a.childDeviceId,
                childName: a.childName ?? 'Bé',
                deviceName: a.deviceName ?? 'Thiết bị',
                screenTimeLimitMinutes: 120,
              ),
            );
            alertMap[a.id] = a.copyWith(
              childName: matchedDev.childName,
              deviceName: matchedDev.deviceName,
            );
          }
        }
      }
    }

    final list = alertMap.values.toList();
    list.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return list;
  }

  List<NoiseEventModel> get _allFilteredEvents {
    final fromDate = _getFromDate();
    final Map<int, NoiseEventModel> eventMap = {};

    for (final dev in _filteredDevices) {
      final history = _histories[dev.id];
      if (history != null) {
        for (final e in history.events) {
          if (fromDate == null || e.measuredAt.isAfter(fromDate)) {
            eventMap[e.id] = e.copyWith(
              childName: dev.childName,
              deviceName: dev.deviceName,
            );
          }
        }
      }
    }

    final list = eventMap.values.toList();
    list.sort((a, b) => a.measuredAt.compareTo(b.measuredAt));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    // TC02: Kiểm tra Role Phụ huynh
    if (!widget.currentUser.isParent) {
      return _buildAccessDeniedState();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Góc An Toàn Gia Đình',
          style: TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _loadAllInsightsData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllInsightsData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorState()
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 14),
                    _buildFiltersSection(),
                    const SizedBox(height: 16),
                    _buildOverviewCardsSection(),
                    const SizedBox(height: 20),
                    _buildSafetySuggestionsSection(),
                    const SizedBox(height: 20),
                    _buildTrendAnalysisSection(),
                    const SizedBox(height: 20),
                    _buildNoiseInsightsSection(),
                    const SizedBox(height: 24),
                    _buildMethodologyDisclosure(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildAccessDeniedState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quyền Truy Cập'),
        backgroundColor: Colors.red.shade800,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.gpp_bad_rounded, size: 64, color: Colors.red.shade700),
              const SizedBox(height: 16),
              const Text(
                'Truy Cập Bị Từ Chối',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Màn hình Góc An Toàn Gia Đình chỉ dành riêng cho tài khoản Phụ huynh để theo dõi an toàn của con. Tài khoản Trẻ em không có quyền truy cập.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Quay Lại Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 54, color: AppColors.error),
            const SizedBox(height: 12),
            const Text(
              'Lỗi Tải Dữ Liệu An Toàn',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Đã có lỗi xảy ra khi kết nối máy chủ backend.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadAllInsightsData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử Lại'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'KidGuard Safety Insights',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Thông tin an toàn từ thiết bị của con',
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
    );
  }

  Widget _buildFiltersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bộ lọc thiết bị
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                selected: _selectedDeviceId == null,
                label: Text('Tất cả thiết bị (${_devices.length})'),
                onSelected: (_) {
                  setState(() => _selectedDeviceId = null);
                },
              ),
              const SizedBox(width: 8),
              ..._devices.map((dev) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: _selectedDeviceId == dev.id,
                    avatar: Icon(
                      dev.isLocked
                          ? Icons.lock_rounded
                          : Icons.phone_android_rounded,
                      size: 14,
                      color: dev.isLocked ? Colors.red : AppColors.primary,
                    ),
                    label: Text(
                      '${dev.childName} (${dev.deviceName})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onSelected: (selected) {
                      setState(() {
                        _selectedDeviceId = selected ? dev.id : null;
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Bộ lọc khoảng thời gian
        SegmentedButton<TimeRangeFilter>(
          segments: const [
            ButtonSegment(
              value: TimeRangeFilter.sevenDays,
              label: Text('7 ngày qua', style: TextStyle(fontSize: 11)),
              icon: Icon(Icons.date_range_rounded, size: 14),
            ),
            ButtonSegment(
              value: TimeRangeFilter.thirtyDays,
              label: Text('30 ngày qua', style: TextStyle(fontSize: 11)),
              icon: Icon(Icons.calendar_month_rounded, size: 14),
            ),
            ButtonSegment(
              value: TimeRangeFilter.all,
              label: Text('Tất cả', style: TextStyle(fontSize: 11)),
              icon: Icon(Icons.history_rounded, size: 14),
            ),
          ],
          selected: {_selectedTimeRange},
          onSelectionChanged: (newSelection) {
            setState(() {
              _selectedTimeRange = newSelection.first;
            });
            _loadAllInsightsData();
          },
        ),
      ],
    );
  }

  Widget _buildOverviewCardsSection() {
    final filteredDevs = _filteredDevices;
    final lockedCount = filteredDevs.where((d) => d.isLocked).length;
    final activeCount = filteredDevs.length - lockedCount;
    final alerts = _allFilteredAlerts;
    final unackCount = alerts.where((a) => !a.isAcknowledged).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tổng Quan Trạng Thái',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                title: 'Tổng thiết bị',
                value: '${filteredDevs.length}',
                subtitle: '${activeCount >= 0 ? activeCount : 0} hoạt động',
                icon: Icons.devices_rounded,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                title: 'Đang khóa (DB)',
                value: '$lockedCount',
                subtitle: lockedCount > 0 ? 'Có thiết bị khóa' : 'Bình thường',
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
              child: _buildMetricCard(
                title: 'Cảnh báo tiếng ồn',
                value: '${alerts.length}',
                subtitle: 'Vượt ngưỡng an toàn',
                icon: Icons.graphic_eq_rounded,
                color: alerts.isNotEmpty
                    ? Colors.amber.shade900
                    : Colors.teal.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricCard(
                title: 'Chưa xác nhận',
                value: '$unackCount',
                subtitle: unackCount > 0 ? 'Cần xem ngay' : 'Đã xem hết',
                icon: Icons.warning_amber_rounded,
                color: unackCount > 0
                    ? Colors.red.shade700
                    : Colors.green.shade700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
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
                    title,
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
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.85),
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

  Widget _buildSafetySuggestionsSection() {
    final alerts = _allFilteredAlerts;
    final allEvents = _allFilteredEvents;
    final lockedDevices = _filteredDevices.where((d) => d.isLocked).toList();

    final List<_RuleSuggestion> suggestions = [];

    // Quy tắc 1: Thiết bị có nhiều lần vượt ngưỡng (> 2 lần)
    final Map<int, int> deviceAlertCounts = {};
    for (final a in alerts) {
      deviceAlertCounts[a.childDeviceId] =
          (deviceAlertCounts[a.childDeviceId] ?? 0) + 1;
    }

    deviceAlertCounts.forEach((devId, count) {
      if (count >= 2) {
        final dev = _devices.firstWhere(
          (d) => d.id == devId,
          orElse: () => ChildDeviceModel(
            id: devId,
            childName: 'Bé',
            deviceName: 'Thiết bị',
            screenTimeLimitMinutes: 120,
          ),
        );
        suggestions.add(
          _RuleSuggestion(
            type: _SuggestionType.warning,
            title: 'Mức ồn vượt ngưỡng thường xuyên',
            message:
                'Thiết bị ${dev.deviceName} của ${dev.childName} có $count lần đo vượt ngưỡng an toàn trong khoảng thời gian này. Phụ huynh có thể kiểm tra lại môi trường xung quanh hoặc điều chỉnh lại ngưỡng tiếng ồn.',
          ),
        );
      }
    });

    // Quy tắc 2: Chưa có cảnh báo nào trong thời gian chọn
    if (alerts.isEmpty && allEvents.isNotEmpty) {
      suggestions.add(
        const _RuleSuggestion(
          type: _SuggestionType.safe,
          title: 'Môi trường an toàn',
          message: 'Chưa ghi nhận cảnh báo trong khoảng thời gian đã chọn. Mọi số đo âm thanh gửi về đều nằm trong ngưỡng an toàn do phụ huynh thiết lập.',
        ),
      );
    }

    // Quy tắc 3: Chưa có dữ liệu đo nào
    if (allEvents.isEmpty) {
      suggestions.add(
        const _RuleSuggestion(
          type: _SuggestionType.info,
          title: 'Chờ dữ liệu đo đạc',
          message: 'Chưa có đủ dữ liệu để đưa ra nhận xét. Khi điện thoại của con thực hiện các phiên đo âm thanh, phân tích an toàn sẽ tự động được cập nhật.',
        ),
      );
    }

    // Quy tắc 4: Thiết bị bị đánh dấu khóa
    if (lockedDevices.isNotEmpty) {
      final names = lockedDevices.map((d) => d.deviceName).join(', ');
      suggestions.add(
        _RuleSuggestion(
          type: _SuggestionType.info,
          title: 'Trạng thái khóa thiết bị',
          message:
              'Hiện có ${lockedDevices.length} thiết bị ($names) đang được đánh dấu khóa trong cơ sở dữ liệu. Phụ huynh có thể mở khóa trong mục Quản lý thiết bị nếu con cần sử dụng.',
        ),
      );
    }

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    Icons.lightbulb_outline_rounded,
                    color: Colors.teal,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Gợi Ý An Toàn (Rule-Based Insights)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...suggestions.map((s) => _buildSuggestionItem(s)),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionItem(_RuleSuggestion s) {
    Color bg;
    Color border;
    Color iconColor;
    IconData icon;

    switch (s.type) {
      case _SuggestionType.warning:
        bg = Colors.amber.shade50;
        border = Colors.amber.shade300;
        iconColor = Colors.amber.shade900;
        icon = Icons.warning_amber_rounded;
        break;
      case _SuggestionType.safe:
        bg = Colors.green.shade50;
        border = Colors.green.shade300;
        iconColor = Colors.green.shade800;
        icon = Icons.check_circle_outline_rounded;
        break;
      case _SuggestionType.info:
        bg = Colors.blue.shade50;
        border = Colors.blue.shade200;
        iconColor = Colors.blue.shade800;
        icon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  s.message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendAnalysisSection() {
    final alerts = _allFilteredAlerts;
    final allEvents = _allFilteredEvents;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Phân Tích Xu Hướng Tiếng Ồn',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (allEvents.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.bar_chart_rounded,
                      size: 40,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Chưa đủ dữ liệu để phân tích xu hướng',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Cần tối thiểu các bản ghi đo âm thanh từ máy con để vẽ biểu đồ xu hướng.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Thống kê tóm tắt từ dữ liệu API
              _buildTrendSummaryMetrics(allEvents),
              const SizedBox(height: 14),
              const Text(
                'Số lần vượt ngưỡng an toàn theo ngày:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              // Biểu đồ cột tự tạo Material 3 (Zero RenderFlex overflow)
              _buildCustomDailyBarChart(alerts),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrendSummaryMetrics(List<NoiseEventModel> allEvents) {
    double totalDb = 0;
    double maxDb = 0;

    for (final e in allEvents) {
      totalDb += e.decibel;
      final peak = e.peakDecibel ?? e.decibel;
      if (peak > maxDb) maxDb = peak;
    }

    final avgDb = allEvents.isNotEmpty ? (totalDb / allEvents.length) : 0.0;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Trung bình đo',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${avgDb.toStringAsFixed(1)} dB',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.purple.shade50.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mức đỉnh ghi nhận',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${maxDb.toStringAsFixed(1)} dB',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomDailyBarChart(List<NoiseEventModel> alerts) {
    // Nhóm số lần vi phạm theo 7 ngày gần nhất
    final now = DateTime.now();
    final List<DateTime> days = List.generate(7, (i) {
      return DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 6 - i));
    });

    final Map<String, int> countsByDay = {};
    for (final day in days) {
      final key = '${day.day}/${day.month}';
      countsByDay[key] = 0;
    }

    for (final a in alerts) {
      final local = a.measuredAt.toLocal();
      final key = '${local.day}/${local.month}';
      if (countsByDay.containsKey(key)) {
        countsByDay[key] = countsByDay[key]! + 1;
      }
    }

    final maxCount = countsByDay.values.fold<int>(
      0,
      (prev, val) => val > prev ? val : prev,
    );
    final chartMax = maxCount > 0 ? maxCount : 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: days.map((day) {
                final key = '${day.day}/${day.month}';
                final count = countsByDay[key] ?? 0;
                final heightFactor = (count / chartMax).clamp(0.08, 1.0);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: count > 0
                                ? Colors.red.shade800
                                : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: heightFactor,
                              widthFactor: 0.8,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: count > 0
                                      ? Colors.red.shade400
                                      : Colors.teal.shade200,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 12),
          Row(
            children: days.map((day) {
              final key = '${day.day}/${day.month}';
              return Expanded(
                child: Text(
                  key,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNoiseInsightsSection() {
    final alerts = _allFilteredAlerts;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Sự Kiện Vượt Ngưỡng Gần Đây',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: alerts.isNotEmpty
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${alerts.length} sự kiện',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: alerts.isNotEmpty
                          ? Colors.red.shade800
                          : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (alerts.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline_rounded,
                      size: 40,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Chưa ghi nhận cảnh báo trong khoảng thời gian đã chọn.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Không có sự kiện vượt ngưỡng âm thanh nào từ thiết bị của con.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...alerts.map((a) => _buildAlertEventItem(a)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlertEventItem(NoiseEventModel alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: alert.isAcknowledged
            ? Colors.grey.shade50
            : Colors.red.shade50.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: alert.isAcknowledged
              ? Colors.grey.shade300
              : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                alert.isAcknowledged
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                size: 16,
                color: alert.isAcknowledged
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${alert.childName ?? "Bé"} — ${alert.deviceName ?? "Thiết bị"}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: alert.isAcknowledged
                      ? Colors.green.shade50
                      : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  alert.isAcknowledged ? 'ĐÃ XEM' : 'CHƯA XEM',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: alert.isAcknowledged
                        ? Colors.green.shade800
                        : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    'Đo: ${alert.decibel.toStringAsFixed(1)} dB',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                    ),
                  ),
                  Text(
                    'Ngưỡng: ${alert.thresholdDb.toStringAsFixed(0)} dB',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              if (!alert.isAcknowledged)
                OutlinedButton(
                  onPressed: () => _handleAcknowledgeAlert(alert.id),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    foregroundColor: Colors.red.shade800,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                  child: const Text(
                    'Xác nhận đã xem',
                    style: TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Thời gian: ${alert.formattedTime}',
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodologyDisclosure() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Góc An Toàn Gia Đình tổng hợp dữ liệu thực tế từ máy của con và ngưỡng do phụ huynh thiết lập. '
              'KidGuard cam kết không khẳng định sức khỏe, tâm lý hay nguy hiểm vật lý của trẻ, tuân thủ đạo đức bảo vệ trẻ em.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SuggestionType { warning, safe, info }

class _RuleSuggestion {
  final _SuggestionType type;
  final String title;
  final String message;

  const _RuleSuggestion({
    required this.type,
    required this.title,
    required this.message,
  });
}
