import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/storage/Storage.dart';
import 'package:castboard_performer/ApplicationSubtitle.dart';
import 'package:castboard_performer/ApplicationTitle.dart';
import 'package:castboard_performer/versionCodename.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ConfigViewer extends StatelessWidget {
  const ConfigViewer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardMaxWidth = MediaQuery.of(context).size.width / 4;
    const hSpacer = SizedBox(width: 16);
    const vSpacer = SizedBox(height: 16);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          const Positioned(
            top: 16,
            left: 16,
            child: Hero(tag: 'application-title', child: ApplicationTitle()),
          ),
          Column(
            children: [
              const Spacer(),
              const Spacer(),
              const Hero(tag: 'application-subtitle', child: ApplicationSubtitle()),
              const Spacer(),
              Text(
                  'Connect your phone, tablet or computer to the following Wireless network.',
                  style: Theme.of(context).textTheme.subtitle1),
              vSpacer,
              _WirelessConfigCard(
                  cardMaxWidth: cardMaxWidth,
                  hSpacer: hSpacer,
                  vSpacer: vSpacer),
              vSpacer,
              Text('Then enter the address below into your browser',
                  style: Theme.of(context).textTheme.subtitle1),
              vSpacer,
              _DashboardAddressCard(
                cardMaxWidth: cardMaxWidth,
              ),
              const Spacer(),
              const _DebugInfoPanel(),
            ],
          ),
        ],
      ),
    );
  }
}

class _DebugInfoPanel extends StatelessWidget {
  const _DebugInfoPanel({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(8),
      foregroundDecoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor)),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.caption!,
        child: Column(
          children: [
            Text('Geek Zone', style: Theme.of(context).textTheme.overline),
            const Text('Build Codename: $kVersionCodename'),
            const Text(
              'kDebugMode: $kDebugMode',
            ),
            Text('Storage Path: ${Storage.instance.appRootStoragePath}'),
            Text(
                'Diagnostics Path: ${LoggingManager.instance.logsStoragePath}'),
            Text(
                'Logger.RunAsRelease: ${LoggingManager.instance.runAsRelease}'),
          ],
        ),
      ),
    );
  }
}

class _DashboardAddressCard extends StatelessWidget {
  final double cardMaxWidth;

  const _DashboardAddressCard({
    Key? key,
    required this.cardMaxWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        constraints: BoxConstraints(maxWidth: cardMaxWidth),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                '192.168.1.1',
                style: Theme.of(context)
                    .textTheme
                    .subtitle1!
                    .copyWith(color: Theme.of(context).colorScheme.secondary),
              ),
            ),
          ),
        ));
  }
}

class _WirelessConfigCard extends StatelessWidget {
  const _WirelessConfigCard({
    Key? key,
    required this.cardMaxWidth,
    required this.hSpacer,
    required this.vSpacer,
  }) : super(key: key);

  final double cardMaxWidth;
  final SizedBox hSpacer;
  final SizedBox vSpacer;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: cardMaxWidth),
      child: Card(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Network Name',
                    style: Theme.of(context).textTheme.subtitle1),
                hSpacer,
                Text('Castboard',
                    style: Theme.of(context)
                        .textTheme
                        .subtitle1!
                        .copyWith(color: Theme.of(context).colorScheme.secondary)),
              ],
            ),
            vSpacer,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Password', style: Theme.of(context).textTheme.subtitle1),
                hSpacer,
                Text('curlybreeze298',
                    style: Theme.of(context)
                        .textTheme
                        .subtitle1!
                        .copyWith(color: Theme.of(context).colorScheme.secondary)),
              ],
            )
          ],
        ),
      )),
    );
  }
}
