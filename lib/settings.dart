import 'dart:io';

import 'package:castboard_performer/address_list_display.dart';
import 'package:flutter/material.dart';

class Settings extends StatefulWidget {
  final int serverPortNumber;
  final void Function() onOpenButtonPressed;

  Settings({
    Key? key,
    required this.onOpenButtonPressed,
    required this.serverPortNumber,
  }) : super(key: key);

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show File
                const _Title(title: 'Show File'),
                _FileSelector(
                  fileName: '',
                  onOpenButtonPressed: widget.onOpenButtonPressed,
                ),

                const SizedBox(height: 32),

                // Remote Control
                const _Title(title: 'Showcaller Remote Control'),
                Text(
                    'Showcaller provides an interface to control Castboard Performer locally on the same device or remotely from another device via a local network connection.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 8),
                OutlinedButton(
                    onPressed: () async {
                      final addresses = await NetworkInterface.list(
                          includeLoopback: false,
                          includeLinkLocal: false,
                          type: InternetAddressType.IPv4);

                      print(addresses);
                    },
                    child: const Text('Open Showcaller')),
                const SizedBox(height: 8),
                Text(
                    'Showcaller can be accessed remotely via a network connection simply by opening a browser and navigating to one of these addresses: ',
                    style: Theme.of(context).textTheme.bodyMedium),
                AddressListDisplay(portNumber: widget.serverPortNumber),

                const SizedBox(height: 32),

                // Web Slideshow.
                const _Title(title: 'Web Slideshow'),
                const Text(
                    'Any remote Smart TV or other device with a Web Browser that is connected to the same local network can display the slide show.'),
                const Text(
                    'To connect a remote Smart TV, access it\'s web browser and navigate to one of the following addresses'),
                AddressListDisplay(
                  portNumber: widget.serverPortNumber,
                  addressSuffix: 'slideshow',
                ),
              ],
            ),
          ),
        ));
  }
}

class _FileSelector extends StatelessWidget {
  final void Function() onOpenButtonPressed;
  final String fileName;

  const _FileSelector({
    Key? key,
    required this.fileName,
    required this.onOpenButtonPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (fileName.isNotEmpty) Text(fileName),
        OutlinedButton(
          onPressed: onOpenButtonPressed,
          child: const Text('Open File'),
        )
      ],
    );
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
