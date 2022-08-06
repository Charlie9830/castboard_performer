import 'package:castboard_performer/service_advertiser/mdns/mdns.dart';
import 'package:castboard_performer/system_controller/DBusLocation.dart';
import 'package:dbus/dbus.dart';

class MdnsLinuxImpl implements MdnsBase {
  final DBusClient _systemBus = DBusClient.system();
  final DBusLocation _avahi = DBusLocation(
      name: 'org.freedesktop.Avahi',
      path: DBusObjectPath('/'),
      interface: 'org.freedesktop.Avahi.EntryGroup');

  @override
  Future<void> advertise() async {
    final object = _avahi.object(_systemBus);

    await object.callMethod(_avahi.interface, 'AddService', [
      const DBusInt32(0), // Interface
      const DBusInt32(-1), // Avahi.IF_UNSPEC
      const DBusInt32(-1), // Avahi.PROTO_UNSPEC
      const DBusString('castboardperformer12345'), // sname
      const DBusString('_http'), // Type
      const DBusString('local'), // Domain
      const DBusString(''), // shost
      const DBusInt16(5003), // Port
      DBusArray.byte([]) // AAY Text record
    ]);

    await object.callMethod(_avahi.interface, 'Commit', []);
    return;
  }

  @override
  Future<void> close() async {
    return;
  }
}
