import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AddressListDisplay extends StatefulWidget {
  final int portNumber;
  final String addressSuffix;
  final bool hideAddresses;

  const AddressListDisplay(
      {Key? key,
      required this.portNumber,
      this.addressSuffix = '',
      this.hideAddresses = false})
      : super(key: key);

  @override
  State<AddressListDisplay> createState() => _AddressListDisplayState();
}

class _AddressListDisplayState extends State<AddressListDisplay> {
  List<ShowcallerAddressModel> _addresses = [];
  bool _fetching = false;

  @override
  void initState() {
    super.initState();

    _fetchAddresses();
  }

  @override
  Widget build(BuildContext context) {
    if (_fetching == false && _addresses.isEmpty) {
      // No interfaces Fallback.
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text('No Network Interfaces detected',
                style: Theme.of(context).textTheme.bodySmall),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextButton(
                onPressed: () => _fetchAddresses(),
                child: const Text('Retry'),
              ),
            )
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 125),
          child: _fetching
              ? Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text('Loading',
                      style: Theme.of(context).textTheme.bodySmall))
              : _Revealer(
                  enabled: widget.hideAddresses,
                  child: SizedBox(
                    width: 600,
                    child: Card(
                      child: ListView(
                        shrinkWrap: true,
                        children: _addresses.map((address) {
                          final fullAddressString =
                              '${address.http.toString()}/${widget.addressSuffix}';
                          return ListTile(
                            leading: _getAddressIcon(address.interfaceName),
                            title: SelectableText(fullAddressString),
                            trailing: Tooltip(
                              message: 'Open in Browser',
                              child: IconButton(
                                icon: const Icon(Icons.open_in_browser),
                                onPressed: () async =>
                                    launchUrl(Uri.parse(fullAddressString)),
                              ),
                            ),
                            subtitle: Text(address.interfaceName),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                )),
    );
  }

  Icon _getAddressIcon(String interfaceName) {
    if (Platform.isMacOS) {
      // MacOS (bsd) uses Arbitrary device naming, so WIFI will appear as En0 or En1.
      return const Icon(Icons.lan_outlined, color: Colors.grey);
    }

    if (interfaceName.contains(RegExp('Wi-Fi|wifi|wi_fi|wlan',
        caseSensitive: false, multiLine: false))) {
      return const Icon(Icons.wifi, color: Colors.grey);
    }

    return const Icon(Icons.settings_ethernet, color: Colors.grey);
  }

  void _fetchAddresses() async {
    setState(() {
      _fetching = true;
    });

    final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        includeLoopback: false,
        type: InternetAddressType.IPv4);

    setState(() {
      _fetching = false;
    });

    final addresses = interfaces
        .where((interface) => interface.addresses.isNotEmpty)
        .map((interface) => ShowcallerAddressModel(
            Uri.http(
                '${interface.addresses.first.address}:${widget.portNumber}'),
            interface.name))
        .toList();

    setState(() {
      _addresses = addresses;
    });
  }
}

class _Revealer extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _Revealer({Key? key, required this.child, this.enabled = true})
      : super(key: key);

  @override
  State<_Revealer> createState() => __RevealerState();
}

class __RevealerState extends State<_Revealer> {
  bool isRevealed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.enabled == false) {
      return widget.child;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 125),
      child: isRevealed
          ? widget.child
          : TextButton(
              onPressed: () => setState(() {
                    isRevealed = true;
                  }),
              child: const Text('Reveal Addresses')),
    );
  }
}

class ShowcallerAddressModel {
  final Uri http;
  final String interfaceName;

  ShowcallerAddressModel(
    this.http,
    this.interfaceName,
  );
}
