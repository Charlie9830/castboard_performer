import 'dart:convert';

import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/models/system_controller/AvailableResolutions.dart';
import 'package:castboard_core/models/system_controller/DeviceResolution.dart';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_performer/system_controller/platform_implementations/rpi_linux/RpiHdmiModes.dart';

class RpiBootConfigModel {
  final int hdmi_mode;

  RpiBootConfigModel({required this.hdmi_mode});

  const RpiBootConfigModel.defaults() : hdmi_mode = 16;

  RpiBootConfigModel copyWith({
    int? hdmi_mode,
  }) {
    return RpiBootConfigModel(
      hdmi_mode: hdmi_mode ?? this.hdmi_mode,
    );
  }

  SystemConfig toSystemConfig() {
    return SystemConfig(
      deviceResolution: rpiHdmiModes[hdmi_mode],
      availableResolutions: AvailableResolutions.defaults(),
      deviceOrientation: null,
      playShowOnIdle: null,
      playerBuildNumber: '',
      playerVersion: '',
      playerBuildSignature: '',
    );
  }

  factory RpiBootConfigModel.fromFileString(String input) {
    final ls = LineSplitter();
    final lines = ls.convert(input);

    RegExp hdmiModePattern = RegExp(r"#hdmi_mode=[0-9]+|hdmi_mode=[0-9]+");

    RpiBootConfigModel config = RpiBootConfigModel.defaults();

    for (var line in lines) {
      // Ignore comment lines.
      if (line.contains('##')) continue;

      final trimmed = line.trim();

      // Match hdmi_mode, but only if it isn't commented out.
      if (hdmiModePattern.hasMatch(trimmed) &&
          hdmiModePattern.stringMatch(trimmed)!.startsWith("#") == false) {
        config = config.copyWith(
            hdmi_mode: int.parse(
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
