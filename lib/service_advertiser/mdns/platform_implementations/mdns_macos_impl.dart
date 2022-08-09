import 'dart:io';

import 'package:castboard_performer/service_advertiser/mdns/mdns.dart';

class MdnsMacOSImpl implements MdnsBase {
  Process? _process;

  @override
  Future<void> advertise(String deviceName) async {
    _process = await _registerMdns(deviceName);
  }

  @override
  Future<void> close() async {
    _process?.kill(ProcessSignal.sigterm);
  }

  Future<Process> _registerMdns(String deviceName) async {
    final process = await Process.start(
        'dns-sd', ['-R', deviceName, '_http', 'local', '8032'],
        runInShell: true);

    return process;
  }
}
