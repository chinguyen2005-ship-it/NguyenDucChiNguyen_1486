class ChildDeviceModel {
  final int id;
  final String childName;
  final String deviceName;
  final int screenTimeLimitMinutes;
  final String? blockedApps;
  final bool isLocked;
  final double latitude;
  final double longitude;
  final String? parentUsername;
  final String? childUsername;
  final DateTime lastUpdated;
  final DateTime? locationUpdatedAt;
  final double noiseThresholdDb;
  final double? lastNoiseDb;
  final DateTime? lastNoiseAt;

  ChildDeviceModel({
    required this.id,
    required this.childName,
    required this.deviceName,
    this.screenTimeLimitMinutes = 120,
    this.blockedApps,
    this.isLocked = false,
    this.latitude = 10.8018,
    this.longitude = 106.7144,
    this.parentUsername,
    this.childUsername,
    DateTime? lastUpdated,
    this.locationUpdatedAt,
    this.noiseThresholdDb = 80.0,
    this.lastNoiseDb,
    this.lastNoiseAt,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory ChildDeviceModel.fromJson(Map<String, dynamic> json) {
    return ChildDeviceModel(
      id: (json['id'] ?? json['Id'] ?? 0) as int,
      childName: (json['childName'] ?? json['ChildName'] ?? '') as String,
      deviceName: (json['deviceName'] ?? json['DeviceName'] ?? '') as String,
      screenTimeLimitMinutes:
          (json['screenTimeLimitMinutes'] ??
                  json['ScreenTimeLimitMinutes'] ??
                  120)
              as int,
      blockedApps: (json['blockedApps'] ?? json['BlockedApps']) as String?,
      isLocked: (json['isLocked'] ?? json['IsLocked'] ?? false) as bool,
      latitude: ((json['latitude'] ?? json['Latitude'] ?? 10.8018) as num)
          .toDouble(),
      longitude: ((json['longitude'] ?? json['Longitude'] ?? 106.7144) as num)
          .toDouble(),
      parentUsername:
          (json['parentUsername'] ?? json['ParentUsername']) as String?,
      childUsername:
          (json['childUsername'] ?? json['ChildUsername']) as String?,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString()) ?? DateTime.now()
          : (json['LastUpdated'] != null
                ? DateTime.tryParse(json['LastUpdated'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
      locationUpdatedAt: json['locationUpdatedAt'] != null
          ? DateTime.tryParse(json['locationUpdatedAt'].toString())
          : (json['LocationUpdatedAt'] != null
                ? DateTime.tryParse(json['LocationUpdatedAt'].toString())
                : null),
      noiseThresholdDb:
          ((json['noiseThresholdDb'] ?? json['NoiseThresholdDb'] ?? 80.0)
                  as num)
              .toDouble(),
      lastNoiseDb: json['lastNoiseDb'] != null
          ? (json['lastNoiseDb'] as num).toDouble()
          : null,
      lastNoiseAt: json['lastNoiseAt'] != null
          ? DateTime.tryParse(json['lastNoiseAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'childName': childName,
      'deviceName': deviceName,
      'screenTimeLimitMinutes': screenTimeLimitMinutes,
      'blockedApps': blockedApps,
      'isLocked': isLocked,
      'latitude': latitude,
      'longitude': longitude,
      'parentUsername': parentUsername,
      'childUsername': childUsername,
      'lastUpdated': lastUpdated.toIso8601String(),
      'noiseThresholdDb': noiseThresholdDb,
    };
  }

  String get formattedScreenTime {
    final hours = screenTimeLimitMinutes ~/ 60;
    final mins = screenTimeLimitMinutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

  List<String> get blockedAppList {
    if (blockedApps == null || blockedApps!.trim().isEmpty) return [];
    return blockedApps!
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  ChildDeviceModel copyWith({
    int? id,
    String? childName,
    String? deviceName,
    int? screenTimeLimitMinutes,
    String? blockedApps,
    bool? isLocked,
    double? latitude,
    double? longitude,
    String? parentUsername,
    String? childUsername,
    DateTime? lastUpdated,
    DateTime? locationUpdatedAt,
    double? noiseThresholdDb,
    double? lastNoiseDb,
    DateTime? lastNoiseAt,
  }) {
    return ChildDeviceModel(
      id: id ?? this.id,
      childName: childName ?? this.childName,
      deviceName: deviceName ?? this.deviceName,
      screenTimeLimitMinutes:
          screenTimeLimitMinutes ?? this.screenTimeLimitMinutes,
      blockedApps: blockedApps ?? this.blockedApps,
      isLocked: isLocked ?? this.isLocked,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      parentUsername: parentUsername ?? this.parentUsername,
      childUsername: childUsername ?? this.childUsername,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      locationUpdatedAt: locationUpdatedAt ?? this.locationUpdatedAt,
      noiseThresholdDb: noiseThresholdDb ?? this.noiseThresholdDb,
      lastNoiseDb: lastNoiseDb ?? this.lastNoiseDb,
      lastNoiseAt: lastNoiseAt ?? this.lastNoiseAt,
    );
  }
}

class ChildDeviceUpsertDto {
  final int? id;
  final String childName;
  final String deviceName;
  final int screenTimeLimitMinutes;
  final String? blockedApps;
  final bool isLocked;
  final double? latitude;
  final double? longitude;
  final String? parentUsername;
  final String? childUsername;
  final double? noiseThresholdDb;

  const ChildDeviceUpsertDto({
    this.id,
    required this.childName,
    required this.deviceName,
    this.screenTimeLimitMinutes = 120,
    this.blockedApps,
    this.isLocked = false,
    this.latitude = 10.8018,
    this.longitude = 106.7144,
    this.parentUsername,
    this.childUsername,
    this.noiseThresholdDb = 80.0,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'childName': childName,
      'deviceName': deviceName,
      'screenTimeLimitMinutes': screenTimeLimitMinutes,
      'isLocked': isLocked,
    };
    if (id != null) map['id'] = id;
    if (blockedApps != null) map['blockedApps'] = blockedApps;
    if (latitude != null) map['latitude'] = latitude;
    if (longitude != null) map['longitude'] = longitude;
    if (parentUsername != null) map['parentUsername'] = parentUsername;
    if (childUsername != null && childUsername!.trim().isNotEmpty) {
      map['childUsername'] = childUsername!.trim();
    }
    if (noiseThresholdDb != null) map['noiseThresholdDb'] = noiseThresholdDb;
    return map;
  }
}
