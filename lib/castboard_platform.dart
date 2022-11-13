import 'dart:io';

import 'package:castboard_core/Environment.dart';

class CastboardPlatform {
  static get isLinuxDesktop =>
      Platform.isLinux && Environment.isElinux == false;

  static get isElinux => Environment.isElinux;

  static get isMacOS => Platform.isMacOS;

  static get isWindows => Platform.isWindows;
}
