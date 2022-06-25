import 'package:castboard_core/models/system_controller/DeviceResolution.dart';

const rpiHdmiModes = <int, DeviceResolution>{
  3: DeviceResolution(640, 480), // 480p
  4: DeviceResolution(1280, 720), // 720p
  16: DeviceResolution(1920, 1080), // 1080p
  97: DeviceResolution(4096, 2160), // 2160p 4k
};
