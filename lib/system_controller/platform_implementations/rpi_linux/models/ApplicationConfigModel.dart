import 'dart:convert';

import 'package:castboard_performer/extensions/string/parseBool.dart';

class ApplicationConfigModel {
  final int deviceRotation;
  final bool playShowOnIdle;
  final String deviceName;

  ApplicationConfigModel({
    required this.deviceRotation,
    required this.playShowOnIdle,
    required this.deviceName,
  });

  const ApplicationConfigModel.defaults()
      : deviceRotation = 0,
        playShowOnIdle = true,
        deviceName = 'Performer';

  factory ApplicationConfigModel.fromFile(String fileContents) {
    if (fileContents.isEmpty) {
      return const ApplicationConfigModel.defaults();
    }

    final map = _parseConfigFile(fileContents);
    const defaults = ApplicationConfigModel.defaults();

    return ApplicationConfigModel(
      deviceRotation:
          int.tryParse(map['deviceRotation'] ?? '') ?? defaults.deviceRotation,
      playShowOnIdle: map['playShowOnIdle'] != null
          ? (map['playShowOnIdle'] as String).parseBool()
          : defaults.playShowOnIdle,
      deviceName: map['deviceName'] ??
          const ApplicationConfigModel.defaults().deviceName,
    );
  }

  ApplicationConfigModel copyWith({
    int? deviceRotation,
    bool? playShowOnIdle,
    String? deviceName,
  }) {
    return ApplicationConfigModel(
      deviceRotation: deviceRotation ?? this.deviceRotation,
      playShowOnIdle: playShowOnIdle ?? this.playShowOnIdle,
      deviceName: deviceName ?? this.deviceName,
    );
  }

  String toConfigFileString() {
    final List<String> lines = [
      "deviceRotation=$deviceRotation",
      "playShowOnIdle=$playShowOnIdle",
      "deviceName=${_sanitizeValue(deviceName)}",
    ];

    return lines.join('\n');
  }
}

String _sanitizeValue(String value) {
  return value.replaceAll('=', '').trim();
  ;
}

Map<String, String> _parseConfigFile(String fileContents) {
  final lines = _splitLines(fileContents);

  return Map.fromEntries(lines.map((line) => _parseLine(line)));
}

List<String> _splitLines(String fileContents) {
  // Performs platform aware line splitting.
  const ls = LineSplitter();
  return ls.convert(fileContents);
}

MapEntry<String, String> _parseLine(String line) {
  final list = line.split('=');
  if (list.length == 2) {
    MapEntry<String, String>(list[0], list[1]);
  }

  return const MapEntry<String, String>('', '');
}
