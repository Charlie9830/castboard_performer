import 'package:castboard_performer/service_advertiser/mdns/mdns.dart';

class MdnsNoopImpl implements MdnsBase {
  @override
  Future<void> advertise(String deviceName, int portNumber) async {
    print('Using MdnsNoopImpl. Device Name = $deviceName');
    return;
  }

  @override
  Future<void> close() async {
    print('Using MdnsNoopImpl');
    return;
  }
}
