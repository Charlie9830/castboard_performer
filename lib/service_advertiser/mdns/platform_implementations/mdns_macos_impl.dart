import 'dart:io';

import 'package:castboard_performer/service_advertiser/mdns/mdns.dart';

class MdnsMacOSImpl implements MdnsBase {
  Process? _process;

  @override
  Future<void> advertise() async {
    _process = await _registerMdns();
  }

  @override
  Future<void> close() async {
    _process?.kill(ProcessSignal.sigterm);
  }

  Future<Process> _registerMdns() async {
    final process = await Process.start(
        'dns-sd', ['-R', 'castboardperformer12345', '_http', 'local', '8032'],
        runInShell: true);

    return process;
  }
}
