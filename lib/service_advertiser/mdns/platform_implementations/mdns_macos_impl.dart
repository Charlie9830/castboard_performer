import 'package:castboard_performer/service_advertiser/mdns/mdns.dart';
import 'package:nsd/nsd.dart';

class MdnsMacOSImpl implements MdnsBase {
  Registration? _registration;
  @override
  Future<void> advertise(String deviceName, int portNumber) async {
    _registration = await register(
        Service(name: deviceName, type: '_http._tcp', port: portNumber));
  }

  @override
  Future<void> close() async {
    if (_registration != null) {
      await unregister(_registration!);
    }
  }
}
