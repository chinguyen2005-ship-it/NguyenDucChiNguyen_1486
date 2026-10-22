import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/device_model.dart';
import '../../models/noise_model.dart';
import '../../services/noise_service.dart';

class NoiseMeterScreen extends StatefulWidget {
  final ChildDeviceModel?
  device; // Có thể truyền thiết bị vào để gửi mẫu lên backend
  final bool isParentViewer; // Phụ huynh (true) hay Trẻ em (false)

  const NoiseMeterScreen({super.key, this.device, this.isParentViewer = true});

  @override
  State<NoiseMeterScreen> createState() => _NoiseMeterScreenState();
}

class _NoiseMeterScreenState extends State<NoiseMeterScreen>
    with SingleTickerProviderStateMixin {
  final _noiseService = NoiseService();
  StreamSubscription<NoiseReadingUpdate>? _subscription;

  double _currentDb = 0.0;
  double _peakDb = 0.0;
  double _meanDb = 0.0;
  bool _isWarning = false;
  bool _isMeasuring = false;
  bool _isSubmitting = false;
  bool _isSimulatedMode = false;

  late double _thresholdDb;
  String? _statusMessage;
  bool? _isStatusSuccess;

  NoiseHistoryModel? _history;
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _thresholdDb = widget.device?.noiseThresholdDb ?? 80.0;
    if (widget.device != null) {
      _loadHistory();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _noiseService.stopMeasurement();
    super.dispose();
  }

  void _toggleMeasurement() {
    if (_isMeasuring) {
      _stopMeasurement();
    } else {
      _startMeasurement();
    }
  }

  void _startMeasurement() {
    setState(() {
      _isMeasuring = true;
      _statusMessage = null;
    });

    _subscription?.cancel();
    _subscription = _noiseService
        .startMeasurement(thresholdDb: _thresholdDb)
        .listen((update) {
          if (!mounted) return;
          setState(() {
            _currentDb = update.currentDb;
            _peakDb = update.peakDb;
            _meanDb = update.meanDb;
            _isWarning = update.isWarning;
            _isSimulatedMode = update.isSimulated;
          });
        });
  }

  void _stopMeasurement() {
    _noiseService.stopMeasurement();
    _subscription?.cancel();
    setState(() {
      _isMeasuring = false;
    });
  }

  Future<void> _loadHistory() async {
    if (widget.device == null) return;
    setState(() => _isLoadingHistory = true);
    final history = await _noiseService.getNoiseHistory(
      widget.device!.id,
      take: 20,
    );
    if (!mounted) return;
    setState(() {
      _history = history;
      _isLoadingHistory = false;
    });
  }

  Future<void> _showEditThresholdDialog() async {
    if (widget.device == null || !widget.isParentViewer) return;
    double tempThreshold = _thresholdDb;
    final newTh = await showDialog<double>(
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
              Flexible(child: Text('Cài Đặt Ngưỡng Cảnh Báo')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${tempThreshold.toInt()} dB',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
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
                'Ngưỡng cảnh báo do Phụ huynh quản lý. Trẻ em không thể tự thay đổi ngưỡng này.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
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

    if (newTh == null || newTh == _thresholdDb) return;

    final res = await _noiseService.updateNoiseThreshold(
      widget.device!.id,
      newTh,
    );
    if (!mounted) return;
    if (res.success) {
      setState(() {
        _thresholdDb = res.thresholdDb ?? newTh;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res.message), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _sendSampleToBackend() async {
    if (widget.device == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng chọn thiết bị trẻ em để gửi mẫu tiếng ồn lên server.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_isSimulatedMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể gửi số đo mô phỏng/demo lên server theo quy định KidGuard.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final reading =
        _noiseService.getLatestReading() ??
        NoiseReadingDto(
          decibel: _currentDb > 0 ? _currentDb : 65.0,
          peakDecibel: _peakDb > 0 ? _peakDb : 75.0,
          durationSeconds: 5,
        );

    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });

    final res = await _noiseService.reportNoise(widget.device!.id, reading);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _isStatusSuccess = res.success;
      if (res.success) {
        _statusMessage = res.isAlert
            ? '${res.message}${res.parentNotifiedByEmail ? " (Đã gửi email cảnh báo tới phụ huynh)" : ""}'
            : res.message;
      } else {
        _statusMessage = res.message;
      }
    });

    if (res.success) {
      _loadHistory();
    }
  }

  Color _getDbColor(double db) {
    if (db < 60) return Colors.green.shade600;
    if (db < _thresholdDb) return Colors.orange.shade700;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _getDbColor(_currentDb);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đo Tiếng Ồn Môi Trường'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (widget.device != null)
            IconButton(
              icon: const Icon(Icons.history_rounded),
              tooltip: 'Làm mới lịch sử',
              onPressed: _loadHistory,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Demo Mode Warning Banner
              if (_isSimulatedMode) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade400),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'CHẾ ĐỘ MÔ PHỎNG (DEMO MODE): Thiết bị không có microphone vật lý. Số đo dB chỉ dùng để thử nghiệm giao diện, không được gửi lên server thật.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Device context card (if opened from a specific device)
              if (widget.device != null) ...[
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.phone_android_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.device!.childName} — ${widget.device!.deviceName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 2,
                                children: [
                                  Text(
                                    'Ngưỡng cảnh báo: ${_thresholdDb.toInt()} dB',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (!widget.isParentViewer)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.lock_outline,
                                            size: 11,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(width: 3),
                                          Text(
                                            'Chỉ đọc',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (widget.isParentViewer)
                          IconButton(
                            icon: const Icon(
                              Icons.tune_rounded,
                              color: AppColors.primary,
                            ),
                            tooltip: 'Chỉnh sửa ngưỡng cảnh báo',
                            onPressed: _showEditThresholdDialog,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Active Measurement Warning Banner
              if (_isMeasuring) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: const Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ĐANG ĐO TIẾNG ỒN VỚI MICROPHONE (Thời gian thực). Tuyệt đối không ghi âm giọng nói hay lưu trữ audio.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Visual Decibel Gauge
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 20,
                  ),
                  child: Column(
                    children: [
                      // Circular dB Meter
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 200,
                            height: 200,
                            child: CircularProgressIndicator(
                              value: (_currentDb / 120.0).clamp(0.0, 1.0),
                              strokeWidth: 16,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                activeColor,
                              ),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentDb > 0
                                    ? _currentDb.toStringAsFixed(1)
                                    : '--',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: activeColor,
                                ),
                              ),
                              const Text(
                                'DECIBEL (dB)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _isWarning
                                      ? Colors.red.shade100
                                      : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _isWarning
                                      ? 'VƯỢT NGƯỠNG'
                                      : (_currentDb > 65
                                            ? 'TIẾNG ỒN VỪA'
                                            : 'YÊN TĨNH'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: _isWarning
                                        ? Colors.red.shade800
                                        : Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Stats Row (Current, Mean, Peak)
                      Wrap(
                        alignment: WrapAlignment.spaceAround,
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          _buildStatItem(
                            'Hiện tại',
                            '${_currentDb.toStringAsFixed(0)} dB',
                            activeColor,
                          ),
                          _buildStatItem(
                            'Trung bình',
                            '${_meanDb.toStringAsFixed(0)} dB',
                            Colors.blue.shade700,
                          ),
                          _buildStatItem(
                            'Đỉnh đo',
                            '${_peakDb.toStringAsFixed(0)} dB',
                            Colors.purple.shade700,
                          ),
                          _buildStatItem(
                            'Ngưỡng',
                            '${_thresholdDb.toInt()} dB',
                            Colors.orange.shade800,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Control Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleMeasurement,
                      icon: Icon(
                        _isMeasuring
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                      ),
                      label: Text(_isMeasuring ? 'Dừng Đo' : 'Bắt Đầu Đo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isMeasuring
                            ? Colors.red.shade700
                            : AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (widget.device != null) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isSubmitting ? null : _sendSampleToBackend,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Gửi Lên Server'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (!widget.isParentViewer) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.cyan.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.cyan.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.privacy_tip_outlined,
                        color: AppColors.secondary,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Quyền Microphone: Bạn có thể bắt đầu và dừng đo bất kỳ lúc nào. Thiết bị chỉ ước lượng cường độ dB tức thời, không nghe lén.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Status Banner
              if (_statusMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isStatusSuccess == true
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isStatusSuccess == true
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isStatusSuccess == true
                            ? Icons.check_circle_outline_rounded
                            : Icons.error_outline_rounded,
                        color: _isStatusSuccess == true
                            ? AppColors.success
                            : AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color: _isStatusSuccess == true
                                ? AppColors.success
                                : AppColors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // History Section (if device provided)
              if (widget.device != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Lịch Sử Cảnh Báo Âm Thanh',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_history != null)
                      Text(
                        'Tổng: ${_history!.count} (Cảnh báo: ${_history!.alertCount})',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                if (_isLoadingHistory)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_history == null || _history!.events.isEmpty)
                  Card(
                    elevation: 0,
                    color: Colors.grey.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'Chưa có dữ liệu sự kiện tiếng ồn nào được ghi nhận cho thiết bị này.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  ..._history!.events.take(5).map((e) {
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: e.isAlert
                              ? Colors.red.shade50
                              : Colors.green.shade50,
                          child: Icon(
                            e.isAlert
                                ? Icons.warning_amber_rounded
                                : Icons.graphic_eq_rounded,
                            size: 18,
                            color: e.isAlert
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                        title: Text(
                          'Mức đo: ${e.decibel.toStringAsFixed(1)} dB (Ngưỡng ${e.thresholdDb.toInt()} dB)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          'Thời điểm: ${e.measuredAt.toLocal().toString().split(".")[0]}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: e.isAlert
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'CẢNH BÁO',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  }),
                const SizedBox(height: 16),
              ],

              // Privacy & Disclaimer Card
              Card(
                elevation: 0,
                color: Colors.orange.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: Colors.orange,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bảo vệ quyền riêng tư & Hiệu chuẩn:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Colors.orange,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Hệ thống chỉ đo cường độ âm thanh tức thời (SPL dB) để phát hiện môi trường ồn ào bất thường. Tuyệt đối KHÔNG ghi âm hoặc lưu trữ bất kỳ cuộc trò chuyện hay tệp âm thanh nào. Giá trị dB là ước lượng theo cảm biến micro điện thoại.',
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.4,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
