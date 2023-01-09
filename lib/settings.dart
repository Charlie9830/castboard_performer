import 'package:castboard_performer/address_list_display.dart';
import 'package:castboard_performer/fullscreen_toggle_button.dart';
import 'package:castboard_performer/launch_local_showcaller.dart';
import 'package:castboard_performer/models/understudy_session_model.dart';
import 'package:castboard_performer/setFullscreen.dart';
import 'package:castboard_performer/understudy_session_display.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class Settings extends StatefulWidget {
  final int serverPortNumber;
  final Map<String, UnderstudySessionModel> understudySessions;

  const Settings({
    Key? key,
    required this.serverPortNumber,
    this.understudySessions = const {},
  }) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool? _isFullscreen;

  @override
  void initState() {
    _fetchFullscreenValue();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          actions: [
            FullscreenToggleButton(
              isFullscreen: _isFullscreen,
              onPressed: (targetState) => setState(() => _isFullscreen = targetState),
            )
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display
                const _Title(title: 'Display'),
                _FullscreenCheckbox(
                    isFullscreen: _isFullscreen, onChanged: _setIsFullscreen),
                const SizedBox(height: 32),

                // Local Control
                const _Title(title: 'Showcaller Local Control'),
                Text('Click below to open Showcaller locally on your device.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                    icon: const Icon(Icons.settings_remote),
                    onPressed: () async {
                      launchLocalShowcaller();
                    },
                    label: const Text('Launch Showcaller')),

                const SizedBox(height: 32),

                // Remote Control
                const _Title(title: 'Showcaller Remote Control'),
                Text(
                    'Showcaller can be accessed remotely via a network connection simply by opening a browser and navigating to one of these addresses. ',
                    style: Theme.of(context).textTheme.bodySmall),
                AddressListDisplay(portNumber: widget.serverPortNumber),

                const SizedBox(height: 32),

                // Understudy.
                const _Title(title: 'Castboard Understudy'),
                Text(
                    'Any remote Smart TV or other device with a Web Browser that is connected to the same local network can display the slide show.',
                    style: Theme.of(context).textTheme.bodySmall),
                Text(
                    'To connect a remote Smart TV, access it\'s web browser and navigate to one of the following addresses',
                    style: Theme.of(context).textTheme.bodySmall),
                AddressListDisplay(
                  portNumber: widget.serverPortNumber,
                  addressSuffix: 'understudy',
                ),
                const SizedBox(height: 16),
                UnderstudySessionDisplay(
                  sessions: widget.understudySessions.values.toList(),
                )
              ],
            ),
          ),
        ));
  }

  void _setIsFullscreen(bool value) async {
    setState(() {
      _isFullscreen = value;
    });

    await setFullScreen(value);
  }

  void _fetchFullscreenValue() async {
    final value = await windowManager.isFullScreen();

    setState(() {
      _isFullscreen = value;
    });
  }
}

class _Title extends StatelessWidget {
  final String title;
  const _Title({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Divider(),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FullscreenCheckbox extends StatelessWidget {
  final bool? isFullscreen;
  final void Function(bool value) onChanged;

  const _FullscreenCheckbox(
      {Key? key, required this.isFullscreen, required this.onChanged})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      child: Row(
        children: [
          const Text('Fullscreen'),
          const SizedBox(width: 24),
          if (isFullscreen == null)
            const SizedBox(
                width: 48, height: 48, child: CircularProgressIndicator()),
          if (isFullscreen != null)
            Checkbox(
                value: isFullscreen,
                onChanged: (value) => onChanged(value ?? false))
        ],
      ),
    );
  }
}
