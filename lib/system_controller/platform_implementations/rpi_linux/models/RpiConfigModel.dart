import 'dart:convert';

class RpiConfigModel {
  final int deviceRotation;

  RpiConfigModel({
    required this.deviceRotation,
  });

  const RpiConfigModel.defaults() : deviceRotation = 0;

  factory RpiConfigModel.fromFile(String fileContents) {
    if (fileContents.isEmpty) {
      return RpiConfigModel.defaults();
    }

    final map = _parseConfigFile(fileContents);
    final defaults = RpiConfigModel.defaults();

    return RpiConfigModel(
      deviceRotation:
          int.tryParse(map['deviceRotation'] ?? '') ?? defaults.deviceRotation,
    );
  }

  String toConfigFileString() {
    final List<String> lines = [
      "deviceRotation=$deviceRotation",
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