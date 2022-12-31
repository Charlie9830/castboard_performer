import 'dart:convert';

class SystemSettingsModel {
  final bool playShowOnIdle;

  SystemSettingsModel({
    required this.playShowOnIdle,
  });

  Map<String, dynamic> toMap() {
    return {
      'playShowOnIdle': playShowOnIdle,
    };
  }

  SystemSettingsModel.initial() : playShowOnIdle = true;

  factory SystemSettingsModel.fromMap(Map<String, dynamic> map) {
    return SystemSettingsModel(
      playShowOnIdle: map['playShowOnIdle'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory SystemSettingsModel.fromJson(String source) =>
      SystemSettingsModel.fromMap(json.decode(source));
}
