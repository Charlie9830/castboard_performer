import 'package:castboard_performer/system_controller/SystemController.dart';

Future<void> scheduleRestart(Duration time, SystemController controller) async {
  await Future.delayed(time, () => controller.reboot());
}
