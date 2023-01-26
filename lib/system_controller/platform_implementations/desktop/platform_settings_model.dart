import 'dart:convert';

import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_performer/server/Server.dart';

class PlatformSettingsModel {
  final bool playShowOnIdle;
  final int serverPort;
  final String deviceId;
  final String deviceName;

  PlatformSettingsModel({
    required this.playShowOnIdle,
    required this.serverPort,
    required this.deviceId,
    required this.deviceName,
  });

  Map<String, dynamic> toMap() {
    return {
      'playShowOnIdle': playShowOnIdle,
      'serverPort': serverPort,
      'deviceId': deviceId,
      'deviceName': deviceName,
    };
  }

  PlatformSettingsModel.initial()
      : playShowOnIdle = true,
        serverPort = kDefaultServerPort,
        deviceId = '',
        deviceName = '';

  factory PlatformSettingsModel.fromSystemConfig(SystemConfig config) {
    return PlatformSettingsModel(
        playShowOnIdle: config.playShowOnIdle ?? false,
        serverPort: config.serverPort,
        deviceId: config.deviceId,
        deviceName: config.deviceName);
  }

  factory PlatformSettingsModel.fromMap(Map<String, dynamic> map) {
    return PlatformSettingsModel(
      playShowOnIdle: map['playShowOnIdle'] ?? false,
      serverPort: map['serverPort']?.toInt() ?? 0,
      deviceId: map['deviceId'] ?? '',
      deviceName: map['deviceName'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory PlatformSettingsModel.fromJson(String source) =>
      PlatformSettingsModel.fromMap(json.decode(source));

  PlatformSettingsModel copyWith({
    bool? playShowOnIdle,
    int? serverPort,
    String? deviceId,
    String? deviceName,
  }) {
    return PlatformSettingsModel(
      playShowOnIdle: playShowOnIdle ?? this.playShowOnIdle,
      serverPort: serverPort ?? this.serverPort,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
    );
  }
}
