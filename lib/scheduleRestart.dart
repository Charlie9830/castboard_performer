import 'package:castboard_player/system_controller/SystemController.dart';

Future<void> scheduleRestart(Duration time, SystemController controller) async {
  await Future.delayed(time, () => controller.reboot());
}
