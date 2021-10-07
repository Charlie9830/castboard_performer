import 'package:flutter/material.dart';
import 'package:dbus/dbus.dart';

class DbusTesting extends StatefulWidget {
  DbusTesting({Key? key}) : super(key: key);

  @override
  _DbusTestingState createState() => _DbusTestingState();
}

class _DbusTestingState extends State<DbusTesting> {
  String _canRestartUnitResult = '';
  String _canPowerOffResult = '';
  String _status = '';
  DateTime? _lastUpdate;
  DBusClient _dbusClient = DBusClient.system();

  @override
  Widget build(BuildContext context) {
    final String lastUpdate = _lastUpdate == null
        ? 'none'
        : '${_lastUpdate!.hour} : ${_lastUpdate!.minute} : ${_lastUpdate!.second}';

    final style = Theme.of(context).textTheme.headline6;
    return Material(
      child: Listener(
        onPointerDown: (_) => _update(),
        child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(_status, style: Theme.of(context).textTheme.headline4),
                  Text(
                    'Last Update at $lastUpdate',
                    style: style,
                  ),
                  Text(
                    'CanRestartUnit: $_canRestartUnitResult',
                    style: style,
                  ),
                  Text(
                    'CanPowerOff: $_canPowerOffResult',
                    style: style,
                  ),
                ],
              ),
            )),
      ),
    );
  }

  void _update() async {
    setState(() {
      _status = 'Updating...';
    });

    final results = await Future.wait([_tryRestartUnit(), _tryCanPoweroff()]);

    setState(() {
      _status = 'Done';
      _canRestartUnitResult = results[0];
      _canPowerOffResult = results[1];
      _lastUpdate = DateTime.now();
    });
  }

  Future<String> _tryRestartUnit() async {
    final object = DBusRemoteObject(_dbusClient,
        name: 'org.freedesktop.systemd1',
        path: DBusObjectPath('/org/freedesktop/systemd1'));

    try {
      final result = await object.callMethod(
          'org.freedesktop.systemd1.Manager',
          'RestartUnit',
          [DBusString('cage@tty7.service'), DBusString('replace')]);

      return result.toString();
    } catch (e) {
      return e.toString();
    }
  }

  Future<String> _tryCanPoweroff() async {
    final object = DBusRemoteObject(_dbusClient,
        name: 'org.freedesktop.login1',
        path: DBusObjectPath('/org/freedesktop/login1'));

    try {
      final result = await object
          .callMethod('org.freedesktop.login1.Manager', 'CanPowerOff', []);

      return result.toString();
    } catch (e) {
      return e.toString();
    }
  }
}
