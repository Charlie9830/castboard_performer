import 'dart:convert';

class StartupConfigModel {
  final int deviceRotation;

  StartupConfigModel({
    required this.deviceRotation,
  });

  const StartupConfigModel.defaults() : deviceRotation = 0;

  factory StartupConfigModel.fromFile(String fileContents) {
    if (fileContents.isEmpty) {
      return StartupConfigModel.defaults();
    }

    final map = _parseConfigFile(fileContents);
    final defaults = StartupConfigModel.defaults();

    return StartupConfigModel(
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
