import 'dart:convert';

import 'package:castboard_performer/server/Server.dart';

class SystemSettingsModel {
  final bool playShowOnIdle;
  final int serverPort;
  final String deviceId;

  SystemSettingsModel({
    required this.playShowOnIdle,
    required this.serverPort,
    required this.deviceId,
  });

  Map<String, dynamic> toMap() {
    return {
      'playShowOnIdle': playShowOnIdle,
      'serverPort': serverPort,
      'deviceId': deviceId,
    };
  }

  SystemSettingsModel.initial()
      : playShowOnIdle = true,
        serverPort = kDefaultServerPort,
        deviceId = '';

  factory SystemSettingsModel.fromMap(Map<String, dynamic> map) {
    return SystemSettingsModel(
      playShowOnIdle: map['playShowOnIdle'] ?? false,
      serverPort: map['serverPort'] ?? kDefaultServerPort,
      deviceId: map['deviceId'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory SystemSettingsModel.fromJson(String source) =>
      SystemSettingsModel.fromMap(json.decode(source));
}
