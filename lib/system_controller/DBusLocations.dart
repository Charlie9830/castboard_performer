import 'package:castboard_player/system_controller/DBusLocation.dart';
import 'package:dbus/dbus.dart';

class DBusLocations {
  static const DBusLocation logindManager = DBusLocation(
      name: 'org.freedesktop.login1',
      path: DBusObjectPath.unchecked('/org/freedesktop/login1'),
      interface: 'org.freedesktop.login1.Manager');

  static const DBusLocation systemdManager = DBusLocation(
      name: 'org.freedesktop.systemd1',
      path: DBusObjectPath.unchecked('/org/freedesktop/systemd1'),
      interface: 'org.freedesktop.systemd1.Manager');
}