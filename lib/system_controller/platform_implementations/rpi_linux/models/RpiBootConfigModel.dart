import 'dart:convert';

import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/models/system_controller/AvailableResolutions.dart';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_performer/system_controller/platform_implementations/rpi_linux/RpiHdmiModes.dart';

class RpiBootConfigModel {
  final int hdmiMode;

  RpiBootConfigModel({required this.hdmiMode});

  const RpiBootConfigModel.defaults() : hdmiMode = 16;

  RpiBootConfigModel copyWith({
    int? hdmiMode,
  }) {
    return RpiBootConfigModel(
      hdmiMode: hdmiMode ?? this.hdmiMode,
    );
  }

  SystemConfig toSystemConfig() {
    return SystemConfig(
      deviceResolution: rpiHdmiModes[hdmiMode],
      availableResolutions: const AvailableResolutions.defaults(),
      deviceOrientation: null,
      playShowOnIdle: null,
      playerBuildNumber: '',
      playerVersion: '',
      playerBuildSignature: '',
    );
  }

  factory RpiBootConfigModel.fromFileString(String input) {
    const ls = LineSplitter();
    final lines = ls.convert(input);

    RegExp hdmiModePattern = RegExp(r"#hdmi_mode=[0-9]+|hdmi_mode=[0-9]+");

    RpiBootConfigModel config = const RpiBootConfigModel.defaults();

    for (var line in lines) {
      // Ignore comment lines.
      if (line.contains('##')) continue;

      final trimmed = line.trim();

      // Match hdmi_mode, but only if it isn't commented out.
      if (hdmiModePattern.hasMatch(trimmed) &&
          hdmiModePattern.stringMatch(trimmed)!.startsWith("#") == false) {
        config = config.copyWith(
            hdmiMode: int.parse(
                _extractValue(hdmiModePattern.stringMatch(trimmed)!)));
      }
    }

    return config;
  }

  static String _extractValue(String line) {
    LoggingManager.instance.systemManager
        .info('Input to _extractValue is $line');
    return line.split('=')[1];
  }
}
