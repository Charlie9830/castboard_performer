import 'package:castboard_core/PerformerDiscoveryInterop.dart';
import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_performer/server/Server.dart';
import 'package:castboard_performer/service_advertiser/mdns/mdns.dart';
import 'package:castboard_performer/service_advertiser/mdns/platform_implementations/linux/avahi_entry_result_model.dart';
import 'package:castboard_performer/service_advertiser/mdns/platform_implementations/linux/network_interface_model.dart';
import 'package:castboard_performer/system_controller/DBusLocation.dart';
import 'package:castboard_performer/system_controller/DBusLocations.dart';
import 'package:dbus/dbus.dart';

class MdnsLinuxImpl implements MdnsBase {
  final DBusClient _systemBus = DBusClient.system();
  final DBusLocation _avahi = const DBusLocation(
      name: 'org.freedesktop.Avahi',
      path: DBusObjectPath.root,
      interface: 'org.freedesktop.Avahi.Server');

  @override
  Future<void> advertise(String deviceName, int portNumber) async {
    final networkInterfaces = await _getNetworkInterfaces();

    if (networkInterfaces.isEmpty) {
      LoggingManager.instance.general.warning(
          'No network interfaces detected via networkd. Unable to advertise service with Avahi');
      return;
    }

    final object = _avahi.object(_systemBus);
    final hostname = await _getHostName(avahiObject: object);

    final entryGroupReturnResults = <AvahiEntryResultModel>[];

    for (final interface in networkInterfaces) {
      entryGroupReturnResults.add(await _createAvahiEntry(
          avahiObject: object,
          deviceName: deviceName,
          hostname: hostname,
          networkInterface: interface));
    }

    // Process results.
    if (entryGroupReturnResults.isEmpty) {
      // Results list is completely empty.
      LoggingManager.instance.general.warning(
          'Failed to create Avahi Entries. Return results list is empty');
      return;
    }

    if (entryGroupReturnResults.every((result) => result.success == false)) {
      // Every return result was a fail.
      LoggingManager.instance.general
          .warning('Failed to create Avahi Entries on any network interface');
      return;
    }

    // Some or all results were a success. Construct a nicely formated table
    // of the results to print into the logs.
    final successEntries = entryGroupReturnResults
        .where((result) => result.success)
        .map((result) => 'SUCCESS    ${result.interfaceName}')
        .join('\n');

    final failedEntries = entryGroupReturnResults
        .where((result) => result.success == false)
        .map((result) => 'FAILED    ${result.interfaceName}')
        .join('\n');

    if (successEntries.isNotEmpty) {
      LoggingManager.instance.general.info(
          'Advertising Service on Avahi. Result table: \n$successEntries \n$failedEntries ');
    }

    return;
  }

  Future<String> _getHostName({required DBusRemoteObject avahiObject}) async {
    try {
      final hostNameResult =
          await avahiObject.callMethod(_avahi.interface, 'GetHostNameFqdn', []);
      final hostName = hostNameResult.returnValues.first.asString();

      return hostName;
    } catch (e, stacktrace) {
      LoggingManager.instance.general
          .warning('Failed to get Hostname from Avahi dbus api', stacktrace);
      return '';
    }
  }

  Future<AvahiEntryResultModel> _createAvahiEntry(
      {required DBusRemoteObject avahiObject,
      required String deviceName,
      required String hostname,
      required NetworkInterfaceModel networkInterface}) async {
    try {
      final result =
          await avahiObject.callMethod(_avahi.interface, 'EntryGroupNew', []);

      if (result.returnValues.isNotEmpty &&
          result.returnValues.first is DBusObjectPath) {
        final objectPath = result.returnValues.first as DBusObjectPath;

        final entryGroup = DBusRemoteObject(_systemBus,
            name: 'org.freedesktop.Avahi', path: objectPath);

        await entryGroup
            .callMethod('org.freedesktop.Avahi.EntryGroup', 'AddService', [
          DBusInt32(networkInterface.index), // Interface
          const DBusInt32(-1), // Avahi.IF_UNSPEC
          const DBusUint32(0), // Avahi.PROTO_UNSPEC
          DBusString('$kMdnsDeviceNamePrefix$deviceName'), // sname
          const DBusString('_http._tcp'), // Type
          const DBusString('local'), // Domain
          DBusString(hostname), // shost
          const DBusUint16(kDefaultServerPort), // Port
          DBusArray(
              DBusSignature.array(DBusSignature.byte), []), // AAY Text record
        ]);

        await entryGroup
            .callMethod('org.freedesktop.Avahi.EntryGroup', 'Commit', []);

        return AvahiEntryResultModel(true, networkInterface.name);
      }

      return AvahiEntryResultModel(false, networkInterface.name);
    } catch (e, stacktrace) {
      LoggingManager.instance.general.warning(
          'Failed to create Avahi Entry for on interface ${networkInterface.name}',
          stacktrace);
      return AvahiEntryResultModel(false, networkInterface.name);
    }
  }

  Future<Iterable<NetworkInterfaceModel>> _getNetworkInterfaces() async {
    final object = DBusLocations.networkdManager.object(_systemBus);
    final results = await object
        .callMethod(DBusLocations.networkdManager.interface, 'ListLinks', []);

    if (results.values.isEmpty) {
      return [];
    }

    final dbusArray = results.values.first;

    if (dbusArray is! DBusArray ||
        dbusArray.children.isEmpty ||
        dbusArray.children.first.signature != DBusSignature('(iso)')) {
      return [];
    }

    final interfaces = dbusArray.children
        .whereType<DBusStruct>()
        .map((child) => NetworkInterfaceModel(child));

    return interfaces.where((interface) => interface.valid == true);
  }

  @override
  Future<void> close() async {
    return;
  }
}
