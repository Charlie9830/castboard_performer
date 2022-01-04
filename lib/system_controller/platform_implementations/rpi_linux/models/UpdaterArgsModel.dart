// Represents the structure of castboard-update args.env configuration file.

class UpdaterArgsModel {
  final String appPath;
  final String updateSourcePath;
  final String updaterConfPath;
  final String appUnitName;
  final String rollbackPath;
  final String outgoingCodename;
  final String incomingCodename;

  UpdaterArgsModel({
    required this.appPath,
    required this.updateSourcePath,
    required this.updaterConfPath,
    required this.appUnitName,
    required this.rollbackPath,
    required this.outgoingCodename,
    required this.incomingCodename,
  });

  String toEnvFileString() {
    return <String>[
      "CASTBOARD_UPDATER_APP_PATH=$appPath",
      "CASTBOARD_UPDATER_UPDATE_SOURCE_PATH=$updateSourcePath",
      "CASTBOARD_UPDATER_CONF_PATH=$updaterConfPath",
      "CASTBOARD_UPDATER_APP_UNIT_NAME=$appUnitName",
      "CASTBOARD_UPDATER_ROLLBACK_PATH=$rollbackPath",
      "CASTBOARD_UPDATER_OUTGOING_CODENAME=$outgoingCodename",
      "CASTBOARD_UPDATER_INCOMING_CODENAME=$incomingCodename",
    ].join("\n");
  }
}
