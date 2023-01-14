import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_core/update_manager/update_check_result.dart';
import 'package:castboard_core/update_manager/update_manager.dart';
import 'package:castboard_performer/address_list_display.dart';
import 'package:castboard_performer/fullscreen_toggle_button.dart';
import 'package:castboard_performer/launch_local_showcaller.dart';
import 'package:castboard_performer/models/understudy_session_model.dart';
import 'package:castboard_performer/network_port_selector.dart';
import 'package:castboard_performer/server/Server.dart';
import 'package:castboard_performer/setFullscreen.dart';
import 'package:castboard_performer/understudy_session_display.dart';
import 'package:castboard_performer/versionCodename.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class Settings extends StatefulWidget {
  final SystemConfig runningConfig;
  final Map<String, UnderstudySessionModel> understudySessions;
  final bool updateReadyToInstall;
  final void Function()? onDownloadUpdate;
  final double? updateDownloadProgress;
  final void Function(SystemConfig config)? onRunningConfigUpdated;

  const Settings({
    Key? key,
    required this.runningConfig,
    this.understudySessions = const {},
    this.updateReadyToInstall = false,
    this.onDownloadUpdate,
    this.updateDownloadProgress,
    this.onRunningConfigUpdated,
  }) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool? _isFullscreen;
  bool? _updateReadyToInstall;

  @override
  void initState() {
    _fetchFullscreenValue();
    super.initState();
  }

  @override
  Widget build(BuildContext _) {
    final concreteUpdateReadyValue =
        _updateReadyToInstall ?? widget.updateReadyToInstall;

    return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          actions: [
            FullscreenToggleButton(
              isFullscreen: _isFullscreen,
              onPressed: (targetState) =>
                  setState(() => _isFullscreen = targetState),
            )
          ],
        ),
        body: Builder(builder: (context) {
          return SingleChildScrollView(
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
                        launchLocalShowcaller(widget.runningConfig.serverPort);
                      },
                      label: const Text('Launch Showcaller')),

                  const SizedBox(height: 32),

                  // Network Settings
                  const _Title(title: 'Network'),
                  NetworkPortSelector(
                    value: widget.runningConfig.serverPort.toString(),
                    onChanged: _handleServerPortChanged,
                  ),

                  const SizedBox(height: 32),

                  // Remote Control
                  const _Title(title: 'Showcaller Remote Control'),
                  Text(
                      'Showcaller can be accessed remotely via a network connection simply by opening a browser and navigating to one of these addresses. ',
                      style: Theme.of(context).textTheme.bodySmall),
                  AddressListDisplay(
                      portNumber: widget.runningConfig.serverPort),

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
                    portNumber: widget.runningConfig.serverPort,
                    addressSuffix: 'understudy',
                  ),
                  const SizedBox(height: 16),
                  UnderstudySessionDisplay(
                    sessions: widget.understudySessions.values.toList(),
                  ),

                  const SizedBox(height: 32),

                  // Software Update
                  const _Title(title: 'Software Update'),
                  Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: widget.updateDownloadProgress != null
                            ? LinearProgressIndicator(
                                value: (widget.updateDownloadProgress ?? 0.0),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        left: 8.0, bottom: 8.0),
                                    child: Text(
                                        'Version ${UpdateManager.instance.currentVersion} ($kVersionCodename)'),
                                  ),
                                  if (concreteUpdateReadyValue == false)
                                    TextButton(
                                        onPressed: () =>
                                            checkForUpdates(context),
                                        child: const Text('Check for Updates')),
                                  if (concreteUpdateReadyValue == true)
                                    ElevatedButton(
                                      onPressed: () => UpdateManager.instance
                                          .executeUpdate(),
                                      child: const Text('Install Update'),
                                    )
                                ],
                              ),
                      ),
                      // Bottom Spacer to clear Snackbars.
                      const SizedBox(height: 48),
                    ],
                  ),
                ],
              ),
            ),
          );
        }));
  }

  void _handleServerPortChanged(int value) {
    widget.onRunningConfigUpdated
        ?.call(widget.runningConfig.copyWith(serverPort: value));
  }

  void checkForUpdates(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(const SnackBar(
      content: Text('Checking for updates..'),
    ));

    final result = await UpdateManager.instance.checkForUpdates();

    if (result.status == UpdateStatus.readyToInstall && mounted) {
      messenger.showSnackBar(SnackBar(
        content: const Text(
          'Update ready to install.',
        ),
        action: SnackBarAction(
            label: 'Install',
            onPressed: () => UpdateManager.instance.executeUpdate()),
      ));

      setState(() {
        _updateReadyToInstall = true;
      });
      return;
    }

    if (result.status == UpdateStatus.readyToDownload && mounted) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'An update is being downloaded. Check back later to install it.'),
      ));

      widget.onDownloadUpdate?.call();

      return;
    }

    if (result.status == UpdateStatus.upToDate && mounted) {
      messenger.showSnackBar(const SnackBar(
        content: Text("You're up to date!"),
      ));

      return;
    }

    if (result.status == UpdateStatus.unknown && mounted) {
      messenger.showSnackBar(const SnackBar(
        content:
            Text("Unable to contact update server. Please try again later."),
      ));

      return;
    }
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
