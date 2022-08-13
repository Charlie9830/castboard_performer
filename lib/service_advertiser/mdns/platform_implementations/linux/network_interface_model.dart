import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:dbus/dbus.dart';

class NetworkInterfaceModel {
  late bool valid;
  late int index;
  late String name;
  late DBusObjectPath path;

  NetworkInterfaceModel(DBusStruct struct) {
    valid = true;

    try {
      // DbusStruct Schema of an example Loopback interface is.
      // DBusStruct([DBusInt32(1), DBusString('lo'), DBusObjectPath('/org/freedesktop/network1/link/_31')])
      index = struct.children[0].asInt32();
      name = struct.children[1].asString();
      path = struct.children[2].asObjectPath();
    } catch (e, stacktrace) {
      LoggingManager.instance.general.warning(
          'Failed to initialize NetworkInterfaceModel of mdns_linux_impl. Provided DBusStruct was invalid',
          stacktrace);
      valid = false;
      index = -1;
      name = '';
      path = DBusObjectPath.root;
    }
  }
}
