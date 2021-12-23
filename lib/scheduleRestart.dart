import 'package:castboard_player/system_controller/SystemController.dart';

Future<void> scheduleRestart(Duration time, SystemController controller) async {
  Future.delayed(time, () => controller.restart());
}
