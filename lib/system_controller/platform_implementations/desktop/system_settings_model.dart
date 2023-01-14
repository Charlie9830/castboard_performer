import 'dart:convert';

import 'package:castboard_performer/server/Server.dart';

class SystemSettingsModel {
  final bool playShowOnIdle;
  final int serverPort;

  SystemSettingsModel({
    required this.playShowOnIdle,
    required this.serverPort,
  });

  Map<String, dynamic> toMap() {
    return {
      'playShowOnIdle': playShowOnIdle,
      'serverPort': serverPort,
    };
  }

  SystemSettingsModel.initial()
      : playShowOnIdle = true,
        serverPort = kDefaultServerPort;

  factory SystemSettingsModel.fromMap(Map<String, dynamic> map) {
    return SystemSettingsModel(
      playShowOnIdle: map['playShowOnIdle'] ?? false,
      serverPort: map['serverPort'] ?? kDefaultServerPort,
    );
  }

  String toJson() => json.encode(toMap());

  factory SystemSettingsModel.fromJson(String source) =>
      SystemSettingsModel.fromMap(json.decode(source));
}
