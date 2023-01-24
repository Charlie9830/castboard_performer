import 'dart:io';

import 'package:castboard_performer/service_advertiser/mdns/platform_implementations/linux/mdns_linux_impl.dart';
import 'package:castboard_performer/service_advertiser/mdns/platform_implementations/mdns_macos_impl.dart';
import 'package:castboard_performer/service_advertiser/mdns/platform_implementations/mdns_noop_impl.dart';
import 'package:castboard_performer/service_advertiser/mdns/platform_implementations/mdns_windows_impl.dart';

abstract class MdnsBase {
  Future<void> advertise(String instanceName, int portNumber);
  Future<void> close();

  MdnsBase();

  static MdnsBase? _instance;

  static MdnsBase instance() {
    _instance ??= _buildInstance();

    return _instance!;
  }

  static MdnsBase _buildInstance() {
    if (Platform.isMacOS) {
      return MdnsMacOSImpl() as MdnsBase;
    }

    if (Platform.isWindows) {
      return MdnsWindowsImpl() as MdnsBase;
    }

    if (Platform.isLinux) {
      return MdnsLinuxImpl() as MdnsBase;
    }

    return MdnsNoopImpl() as MdnsBase;
  }
}
