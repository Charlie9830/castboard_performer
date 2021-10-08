import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_player/system_controller/SystemController.dart';
import 'package:dbus/dbus.dart';
import 'package:castboard_player/system_controller/DBusLocations.dart';

const String _unitName = 'cage@tty7';

class SystemControllerLinux implements SystemController {
  DBusClient _systemBus = DBusClient.system();

  /// Triggers a hardware Power Off.
  Future<void> powerOff() async {
    final object = DBusLocations.logindManager.object(_systemBus);

    try {
      await object.callMethod(
        DBusLocations.logindManager.interface,
        'PowerOff',
        [DBusBoolean(false)],
      );
    } catch (e) {
      _handleError(e, 'PowerOff');
    }
  }

  /// Triggers a hardware reboot.
  Future<void> reboot() async {
    final object = DBusLocations.logindManager.object(_systemBus);

    try {
      await object.callMethod(
        DBusLocations.logindManager.interface,
        'Reboot',
        [DBusBoolean(false)],
      );
    } catch (e) {
      _handleError(e, 'PowerOff');
    }
  }

  Future<void> restart() async {
    final object = DBusLocations.systemdManager.object(_systemBus);

    try {
      await object.callMethod(
        DBusLocations.systemdManager.interface,
        'RestartUnit',
        [
          DBusString(_unitName), // Unit
          DBusString(
              'replace'), // Restart Mode, one of 'replace', 'fail', 'isolate', 'ignore-dependencies' or 'ignore-requirements'.
        ],
      );
    } catch (e) {
      _handleError(e, 'PowerOff');
    }
  }

  void _handleError(Object e, String call) {
    LoggingManager.instance.systemManager.warning(
        'An exception was thrown whilst calling $call - ${e.toString()}');
  }

  @override
  Future<void> dispose() {
    return _systemBus.close();
  }
}
