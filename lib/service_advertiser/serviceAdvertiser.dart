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

  late final RawDatagramSocket _discoverySocket;
  late final RawDatagramSocket _unicastSocket;
  late final OnConnectivityPingCallback _onConnectivityPingCallback;
  late final MdnsBase _multicastDnsService;

  static Future<void> initialize(
      OnConnectivityPingCallback onConnectivityPingCallback) async {
    // Discovery Socket.
    final discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, pdi.discoveryPort);
    discoverySocket.readEventsEnabled = true;
    discoverySocket.joinMulticast(InternetAddress(pdi.multicastAddress));

    // Unicast Socket
    final unicastSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4, pdi.unicastConnectivityPort);
    unicastSocket.readEventsEnabled = true;

    _instance = ServiceAdvertiser(
      discoverySocket,
      unicastSocket,
      onConnectivityPingCallback,
    );
  }

  ServiceAdvertiser(
    RawDatagramSocket discoverySocket,
    RawDatagramSocket unicastSocket,
    OnConnectivityPingCallback onConnectivityPingCallback,
  )   : _discoverySocket = discoverySocket,
        _unicastSocket = unicastSocket,
        _onConnectivityPingCallback = onConnectivityPingCallback {
    // Attach Listener to the direct Discovery Socket.
    _discoverySocket.listen(_discoverySocketListener);

    // Attach Listener to the Unicast Socket.
    _unicastSocket.listen(_unicastSocketListener);

    _multicastDnsService = MdnsBase.instance();
    _multicastDnsService.advertise();
  }

  Future<void> _discoverySocketListener(RawSocketEvent event) async {
    if (event == RawSocketEvent.read) {
      Datagram? dg = _discoverySocket.receive();

      if (dg == null) {
        return;
      }

      if (pdi.hasMagicBytes(dg.data)) {
        // Discovery Packet
        _discoverySocket.send(pdi.discoveryReplyPayload, dg.address, dg.port);
        return;
      }
    }
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
    _discoverySocket.close();
  }
}
