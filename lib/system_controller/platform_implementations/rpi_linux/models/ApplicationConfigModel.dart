import 'dart:convert';

import 'package:castboard_performer/extensions/string/parseBool.dart';

class ApplicationConfigModel {
  final int deviceRotation;
  final bool playShowOnIdle;

  ApplicationConfigModel({
    required this.deviceRotation,
    required this.playShowOnIdle,
  });

  const ApplicationConfigModel.defaults()
      : deviceRotation = 0,
        playShowOnIdle = true;

  factory ApplicationConfigModel.fromFile(String fileContents) {
    if (fileContents.isEmpty) {
      return ApplicationConfigModel.defaults();
    }

    final map = _parseConfigFile(fileContents);
    final defaults = ApplicationConfigModel.defaults();

    return ApplicationConfigModel(
      deviceRotation:
          int.tryParse(map['deviceRotation'] ?? '') ?? defaults.deviceRotation,
      playShowOnIdle: map['playShowOnIdle'] != null
          ? (map['playShowOnIdle'] as String).parseBool()
          : defaults.playShowOnIdle,
    );
  }

  ApplicationConfigModel copyWith({
    int? deviceRotation,
    bool? playShowOnIdle,
  }) {
    return ApplicationConfigModel(
        deviceRotation: deviceRotation ?? this.deviceRotation,
        playShowOnIdle: playShowOnIdle ?? this.playShowOnIdle);
  }

  String toConfigFileString() {
    final List<String> lines = [
      "deviceRotation=$deviceRotation",
      "playShowOnIdle=$playShowOnIdle"
    ];

    return lines.join('\n');
  }
}

Map<String, String> _parseConfigFile(String fileContents) {
  final lines = _splitLines(fileContents);

  return Map.fromEntries(lines.map((line) => _parseLine(line)));
}

List<String> _splitLines(String fileContents) {
  // Performs platform aware line splitting.
  final ls = LineSplitter();
  return ls.convert(fileContents);
}

MapEntry<String, String> _parseLine(String line) {
  final list = line.split('=');
  if (list.length == 2) {
    MapEntry<String, String>(list[0], list[1]);
  }

  return MapEntry<String, String>('', '');
}
