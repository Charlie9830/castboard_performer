import 'package:castboard_core/models/system_controller/SystemConfig.dart';

class SystemConfigCommitResult {
  final bool success;
  final bool restartRequired;
  final SystemConfig resultingConfig;

  SystemConfigCommitResult({
    required this.success,
    required this.restartRequired,
    required this.resultingConfig,
  });
}
