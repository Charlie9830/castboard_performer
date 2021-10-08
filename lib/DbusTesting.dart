import 'package:castboard_player/system_controller/SystemController.dart';
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

  void _update() {
    final controller = SystemController();

    controller.powerOff();
    controller.reboot();
    controller.restart();
  }
}
