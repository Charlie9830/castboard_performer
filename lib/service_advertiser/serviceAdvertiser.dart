import 'dart:convert';
import 'dart:io';

import 'package:castboard_core/PerformerDiscoveryInterop.dart' as pdi;
import 'package:castboard_core/models/performerDeviceModel.dart';
import 'package:castboard_performer/service_advertiser/mdns/mdns.dart';

typedef OnConnectivityPingCallback = Future<PerformerDeviceModel> Function();

class ServiceAdvertiser {
  static ServiceAdvertiser? _instance;

  static ServiceAdvertiser get instance {
    if (_instance == null) {
      throw 'Ensure ServiceAdvertiser.initialize() has been called before accessing instance property';
    }

    return _instance!;
  }

  late final RawDatagramSocket _unicastSocket;
  late final OnConnectivityPingCallback _onConnectivityPingCallback;
  late final MdnsBase _multicastDnsService;
  late final String _deviceName;

  static Future<void> initialize(
      String deviceName, OnConnectivityPingCallback onConnectivityPingCallback,
      {int mdnsPort = 8081}) async {
    // Unicast Socket
    final unicastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, pdi.unicastConnectivityPort);
    unicastSocket.readEventsEnabled = true;

    // OS Multicast DNS Service
    final multicastDnsService = MdnsBase.instance();
    print('Advertising as $mdnsPort');
    await multicastDnsService.advertise(
      deviceName,
      mdnsPort,
    );

    _instance = ServiceAdvertiser(
      unicastSocket: unicastSocket,
      onConnectivityPingCallback: onConnectivityPingCallback,
      deviceName: deviceName,
      multicastDnsService: multicastDnsService,
    );
  }

  ServiceAdvertiser({
    required RawDatagramSocket unicastSocket,
    required OnConnectivityPingCallback onConnectivityPingCallback,
    required String deviceName,
    required MdnsBase multicastDnsService,
  })  : _unicastSocket = unicastSocket,
        _onConnectivityPingCallback = onConnectivityPingCallback,
        _deviceName = deviceName,
        _multicastDnsService = multicastDnsService {
    // Attach Listener to the Unicast Socket.
    _unicastSocket.listen(_unicastSocketListener);
  }

  Future<void> _unicastSocketListener(RawSocketEvent event) async {
    if (event == RawSocketEvent.read) {
      Datagram? dg = _unicastSocket.receive();

      if (dg == null) {
        return;
      }

      if (pdi.hasMagicBytes(dg.data)) {
        // Unicast Connectivity Packet.
        final partialDeviceDetails = await _onConnectivityPingCallback();
        final fullDeviceDetails = partialDeviceDetails.copyWith(
          deviceName: _deviceName,
          connectivityState: PerformerConnectivityState.full,
          ipAddress: dg.address.address,
          port: dg.port,
        );

        _unicastSocket.send(
            utf8.encode(fullDeviceDetails.toJson()), dg.address, dg.port);
        return;
      }
    }
  }

  Future<void> stop() async {
    _multicastDnsService.close();
    _unicastSocket.close();
  }
}
