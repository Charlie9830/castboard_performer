import 'package:flutter/material.dart';

class ConfigViewer extends StatelessWidget {
  const ConfigViewer({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardMaxWidth = MediaQuery.of(context).size.width / 4;
    final hSpacer = const SizedBox(width: 16);
    final vSpacer = const SizedBox(height: 16);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Text('Castboard', style: Theme.of(context).textTheme.headline1),
          Column(
            children: [
              Text('No Showfile Loaded',
                  style: Theme.of(context).textTheme.headline6),
              vSpacer,
              Text(
                  'Please follow the instructions below to upload a your Showfile',
                  style: Theme.of(context).textTheme.subtitle1),
              vSpacer,
              vSpacer,
            ],
          ),
          Spacer(),
          Text(
              'Connect your phone, tablet or computer to the following Wireless Network',
              style: Theme.of(context).textTheme.subtitle1),
          vSpacer,
          _WirelessConfigCard(
              cardMaxWidth: cardMaxWidth, hSpacer: hSpacer, vSpacer: vSpacer),
          vSpacer,
          Text(
              'Enter the following address into your browser to access the Configuration Dashboard, Follow the instructions there to upload your Showfile',
              style: Theme.of(context).textTheme.subtitle1),
          vSpacer,
          _DashboardAddressCard(
            cardMaxWidth: cardMaxWidth,
          ),
          Spacer(),
        ],
      ),
    );
  }
}

class _DashboardAddressCard extends StatelessWidget {
  final double cardMaxWidth;

  const _DashboardAddressCard({
    Key key,
    @required this.cardMaxWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        constraints: BoxConstraints(maxWidth: cardMaxWidth),
        child: Card(
            child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: Text('dashboard.castboard.net',
                        style: Theme.of(context).textTheme.subtitle1.copyWith(
                            color: Theme.of(context).accentColor))))));
  }
}

class _WirelessConfigCard extends StatelessWidget {
  const _WirelessConfigCard({
    Key key,
    @required this.cardMaxWidth,
    @required this.hSpacer,
    @required this.vSpacer,
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
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Network Name',
                    style: Theme.of(context).textTheme.subtitle1),
                hSpacer,
                Text('CastboardPlayer298',
                    style: Theme.of(context)
                        .textTheme
                        .subtitle1
                        .copyWith(color: Theme.of(context).accentColor)),
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
                        .subtitle1
                        .copyWith(color: Theme.of(context).accentColor)),
              ],
            )
          ],
        ),
      )),
    );
  }
}
