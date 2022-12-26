import 'package:castboard_performer/ApplicationSubtitle.dart';
import 'package:castboard_performer/ApplicationTitle.dart';
import 'package:castboard_performer/address_list_display.dart';
import 'package:castboard_performer/launch_local_showcaller.dart';
import 'package:castboard_performer/models/understudy_session_model.dart';
import 'package:castboard_performer/server/Server.dart';
import 'package:castboard_performer/setFullscreen.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class NoShowSplash extends StatelessWidget {
  const NoShowSplash({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const vSpacer = SizedBox(height: 16);
    return Material(
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodyMedium!,
        textAlign: TextAlign.center,
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              const Positioned(
                top: 16,
                left: 16,
                child:
                    Hero(tag: 'application-title', child: ApplicationTitle()),
              ),
              Positioned(top: 16, right: 16, child: _FullscreenToggle()),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Hero(
                              tag: 'application-subtitle',
                              child: ApplicationSubtitle()),
                          const SizedBox(height: 32),
                          const Text(
                              'To open your show file, press below to launch Castboard Showcaller. \n Here you can load your show file into Performer and adjust cast changes instantly.'),
                          vSpacer,
                          vSpacer,
                          vSpacer,
                          OutlinedButton.icon(
                            icon: const Icon(Icons.settings_remote),
                            onPressed: () async {
                              launchLocalShowcaller();
                            },
                            label: const Text('Launch Showcaller'),
                          ),
                        ],
                      ),
                    ),
                    vSpacer,
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: const [
                                Icon(
                                  Icons.settings_remote,
                                  color: Colors.grey,
                                  size: 32,
                                ),
                                vSpacer,
                                Text(
                                  'Alternatively Showcaller can be accessed from another device via a network connection simply by opening a browser and navigating to one of the below addresses on that device.',
                                ),
                                AddressListDisplay(
                                  portNumber: kServerPort,
                                  hideAddresses: true,
                                )
                              ],
                            ),
                          ),
                          const VerticalDivider(),
                          Expanded(
                            child: Column(
                              children: const [
                                Icon(Icons.connected_tv,
                                    color: Colors.grey, size: 32),
                                vSpacer,
                                Text(
                                    'Any Smart TV or device with a Web Browser that is connected to the same network can display the slide show in addition to this device.'),
                                Text(
                                    'To start playback on a remote device, access it\'s web browser and navigate to one of the following addresses'),
                                AddressListDisplay(
                                  portNumber: kServerPort,
                                  hideAddresses: true,
                                  addressSuffix: 'understudy',
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    vSpacer,
                    const Text(
                        'Press Escape at any time to access these settings again'),
                    vSpacer,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenToggle extends StatefulWidget {
  _FullscreenToggle({Key? key}) : super(key: key);

  @override
  State<_FullscreenToggle> createState() => __FullscreenToggleState();
}

class __FullscreenToggleState extends State<_FullscreenToggle> {
  bool? _isFullscreen;

  @override
  void initState() {
    _fetchFullscreenValue();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen == null) {
      return SizedBox.fromSize(size: Size.zero);
    }

    return TextButton.icon(
      onPressed: _toggleFullscreen,
      icon: _isFullscreen!
          ? const Icon(Icons.fullscreen_exit)
          : const Icon(Icons.fullscreen),
      label: _isFullscreen!
          ? const Text('Exit Fullscreen')
          : const Text('Enter Fullscreen'),
    );
  }

  void _toggleFullscreen() async {
    final targetState = _isFullscreen == null ? false : !_isFullscreen!;
    setState(() {
      _isFullscreen = targetState;
    });

    await setFullScreen(targetState);
  }

  void _fetchFullscreenValue() async {
    final value = await windowManager.isFullScreen();

    setState(() {
      _isFullscreen = value;
    });
  }
}
