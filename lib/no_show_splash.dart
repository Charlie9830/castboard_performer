import 'package:castboard_performer/ApplicationSubtitle.dart';
import 'package:castboard_performer/ApplicationTitle.dart';
import 'package:castboard_performer/address_list_display.dart';
import 'package:castboard_performer/server/Server.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class NoShowSplash extends StatelessWidget {
  const NoShowSplash({Key? key}) : super(key: key);

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
              Column(
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
                            'To open your show file, press below to launch Castboard Showcaller. \n Here you can send your show file to Performer and adjust cast changes instantly'),
                        vSpacer,
                        vSpacer,
                        vSpacer,
                        OutlinedButton.icon(
                          icon: const Icon(Icons.settings_remote),
                          onPressed: () async {
                            launchUrl(Uri.http('localhost:$kServerPort'));
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
                                'Alternatively Showcaller can be accessed remotely via a network connection simply by opening a browser and navigating to one of these addresses.',
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
                                  'Any Smart TV or device with a Web Browser that is connected to the same network can display the slide show.'),
                              Text(
                                  'To playback on a remove device, access it\'s web browser and navigate to one of the following addresses'),
                              AddressListDisplay(
                                portNumber: kServerPort,
                                hideAddresses: true,
                                addressSuffix: 'slideshow',
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
            ],
          ),
        ),
      ),
    );
  }
}
