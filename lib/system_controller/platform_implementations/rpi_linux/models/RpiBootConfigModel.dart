import 'package:castboard_core/models/system_controller/AvailableResolutions.dart';
import 'package:castboard_core/models/system_controller/DeviceResolution.dart';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_player/system_controller/platform_implementations/rpi_linux/RpiHdmiModes.dart';

class RpiBootConfigModel {
  final int hdmi_mode;

  RpiBootConfigModel({required this.hdmi_mode});

  RpiBootConfigModel.defaults() : hdmi_mode = 16;

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
    );
  }

  factory RpiBootConfigModel.fromFileString(String input) {
    final lines = input.split('\n');

    RegExp hdmiModeMatch = RegExp(r"^hdmi_mode=[0-9]+");
    int hdmi_mode = 16;

    for (var line in lines) {
      if (line.contains(hdmiModeMatch))
        hdmi_mode = int.parse(
            _extractValue(hdmiModeMatch.firstMatch(line)!.toString()));
    }

    return RpiBootConfigModel(hdmi_mode: hdmi_mode);
  }

  static String _extractValue(String line) {
    return line.split('=')[1];
  }
}
