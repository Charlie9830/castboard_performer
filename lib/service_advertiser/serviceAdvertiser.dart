import 'dart:convert';
import 'dart:io';

import 'package:castboard_core/PerformerDiscoveryInterop.dart' as pdi;
import 'package:castboard_core/models/performerDeviceModel.dart';

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
    _discoverySocket.listen(_discoverySocketListener);
    _unicastSocket.listen(_unicastSocketListener);
  }

  Future<void> _discoverySocketListener(RawSocketEvent event) async {
    if (event == RawSocketEvent.read) {
      Datagram? dg = _discoverySocket.receive();
      print("Discovery Socket");

      if (dg == null) {
        return;
      }

      if (pdi.hasMagicBytes(dg.data)) {
        // Discovery Packet
        print('Received Discovery Datagram');
        print('Would be sending to ${dg.address}:${dg.port}');
        _discoverySocket.send(pdi.discoveryReplyPayload, dg.address, dg.port);
        return;
      }
    }
  }

  Future<void> _unicastSocketListener(RawSocketEvent event) async {
    if (event == RawSocketEvent.read) {
      Datagram? dg = _unicastSocket.receive();

      print("Unicast Socket");
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

        print('I would be sending to ${dg.address}:${dg.port}');
        _unicastSocket.send(
            utf8.encode(fullDeviceDetails.toJson()), dg.address, dg.port);
        return;
      }
    }
  }
}
