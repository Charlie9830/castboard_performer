
import 'package:castboard_performer/service_advertiser/mdns/mdns.dart';

class MdnsNoopImpl implements MdnsBase {
  @override
  Future<void> advertise() async {
    print('Using MdnsNoopImpl');
    return;
  }

  @override
  Future<void> close() async {
    print('Using MdnsNoopImpl');
    return;
  }
}
