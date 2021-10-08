import 'package:dbus/dbus.dart';

class DBusLocation {
  final String name;
  final DBusObjectPath path;
  final String interface;

  const DBusLocation({
    required this.name,
    required this.path,
    required this.interface,
  });

  DBusRemoteObject object(DBusClient client) {
    return DBusRemoteObject(client, name: name, path: path);
  }
}
