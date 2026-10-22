class NoiseReadingDto {
  final double decibel;
  final double? peakDecibel;
  final int durationSeconds;
  final DateTime? measuredAt;

  const NoiseReadingDto({
    required this.decibel,
    this.peakDecibel,
    this.durationSeconds = 5,
    this.measuredAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'decibel': decibel,
      if (peakDecibel != null) 'peakDecibel': peakDecibel,
      'durationSeconds': durationSeconds,
      'measuredAt': (measuredAt ?? DateTime.now()).toUtc().toIso8601String(),
    };
  }
}

class NoiseEventModel {
  final int id;
  final double decibel;
  final double? peakDecibel;
  final int durationSeconds;
  final double thresholdDb;
  final bool isAlert;
  final bool isAcknowledged;
  final DateTime measuredAt;
  final int childDeviceId;
  final String? childName;
  final String? deviceName;

  NoiseEventModel({
    required this.id,
    required this.decibel,
    this.peakDecibel,
    required this.durationSeconds,
    required this.thresholdDb,
    required this.isAlert,
    required this.isAcknowledged,
    required this.measuredAt,
    required this.childDeviceId,
    this.childName,
    this.deviceName,
  });

  String get formattedTime {
    final local = measuredAt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year;
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $h:$min';
  }

  NoiseEventModel copyWith({
    int? id,
    double? decibel,
    double? peakDecibel,
    int? durationSeconds,
    double? thresholdDb,
    bool? isAlert,
    bool? isAcknowledged,
    DateTime? measuredAt,
    int? childDeviceId,
    String? childName,
    String? deviceName,
  }) {
    return NoiseEventModel(
      id: id ?? this.id,
      decibel: decibel ?? this.decibel,
      peakDecibel: peakDecibel ?? this.peakDecibel,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      thresholdDb: thresholdDb ?? this.thresholdDb,
      isAlert: isAlert ?? this.isAlert,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
      measuredAt: measuredAt ?? this.measuredAt,
      childDeviceId: childDeviceId ?? this.childDeviceId,
      childName: childName ?? this.childName,
      deviceName: deviceName ?? this.deviceName,
    );
  }

  factory NoiseEventModel.fromJson(Map<String, dynamic> json) {
    final rawDecibel = ((json['decibel'] ?? json['Decibel'] ?? 0) as num)
        .toDouble();
    final rawThreshold =
        ((json['thresholdDb'] ?? json['ThresholdDb'] ?? 80) as num).toDouble();
    final rawAlert = json['isAlert'] ?? json['IsAlert'];
    final rawAck = json['isAcknowledged'] ?? json['IsAcknowledged'];

    final isAlert = rawAlert != null
        ? (rawAlert as bool)
        : (rawDecibel >= rawThreshold || json['childName'] != null);
    final isAck = rawAck != null ? (rawAck as bool) : false;

    return NoiseEventModel(
      id: (json['id'] ?? json['Id'] ?? 0) as int,
      decibel: rawDecibel,
      peakDecibel: ((json['peakDecibel'] ?? json['PeakDecibel']) as num?)
          ?.toDouble(),
      durationSeconds:
          (json['durationSeconds'] ?? json['DurationSeconds'] ?? 0) as int,
      thresholdDb: rawThreshold,
      isAlert: isAlert,
      isAcknowledged: isAck,
      measuredAt: json['measuredAt'] != null
          ? DateTime.parse(json['measuredAt'].toString())
          : (json['MeasuredAt'] != null
                ? DateTime.parse(json['MeasuredAt'].toString())
                : DateTime.now()),
      childDeviceId:
          (json['childDeviceId'] ?? json['ChildDeviceId'] ?? 0) as int,
      childName: (json['childName'] ?? json['ChildName']) as String?,
      deviceName: (json['deviceName'] ?? json['DeviceName']) as String?,
    );
  }
}

class NoiseHistoryModel {
  final int deviceId;
  final String childName;
  final double noiseThresholdDb;
  final double? lastNoiseDb;
  final DateTime? lastNoiseAt;
  final int count;
  final int alertCount;
  final double? averageDb;
  final double? maxDb;
  final List<NoiseEventModel> events;

  NoiseHistoryModel({
    required this.deviceId,
    required this.childName,
    required this.noiseThresholdDb,
    this.lastNoiseDb,
    this.lastNoiseAt,
    required this.count,
    required this.alertCount,
    this.averageDb,
    this.maxDb,
    required this.events,
  });

  factory NoiseHistoryModel.fromJson(Map<String, dynamic> json) {
    final rawEvents =
        (json['events'] ?? json['Events']) as List<dynamic>? ?? [];
    final eventsList = rawEvents
        .map((e) => NoiseEventModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return NoiseHistoryModel(
      deviceId: (json['deviceId'] ?? json['DeviceId'] ?? 0) as int,
      childName: (json['childName'] ?? json['ChildName'] ?? '') as String,
      noiseThresholdDb:
          ((json['noiseThresholdDb'] ?? json['NoiseThresholdDb'] ?? 80) as num)
              .toDouble(),
      lastNoiseDb: ((json['lastNoiseDb'] ?? json['LastNoiseDb']) as num?)
          ?.toDouble(),
      lastNoiseAt: json['lastNoiseAt'] != null
          ? DateTime.parse(json['lastNoiseAt'].toString())
          : (json['LastNoiseAt'] != null
                ? DateTime.parse(json['LastNoiseAt'].toString())
                : null),
      count: (json['count'] ?? json['Count'] ?? eventsList.length) as int,
      alertCount: (json['alertCount'] ?? json['AlertCount'] ?? 0) as int,
      averageDb: ((json['averageDb'] ?? json['AverageDb']) as num?)?.toDouble(),
      maxDb: ((json['maxDb'] ?? json['MaxDb']) as num?)?.toDouble(),
      events: eventsList,
    );
  }
}
