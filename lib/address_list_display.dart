import 'dart:io';

import 'package:flutter/material.dart';

class AddressListDisplay extends StatefulWidget {
  final int portNumber;
  final String addressSuffix;
  const AddressListDisplay(
      {Key? key, required this.portNumber, this.addressSuffix = ''})
      : super(key: key);

  @override
  State<AddressListDisplay> createState() => _AddressListDisplayState();
}

class _AddressListDisplayState extends State<AddressListDisplay> {
  List<ShowcallerAddressModel> _addresses = [];

  @override
  void initState() {
    super.initState();

    _fetchAddresses();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 125),
          child: _addresses.isEmpty
              ? Text('Loading', style: Theme.of(context).textTheme.bodySmall)
              : ListView(
                  shrinkWrap: true,
                  children: _addresses
                      .map((address) => ListTile(
                            leading: _getAddressIcon(address.interfaceName),
                            title: SelectableText(
                                '${address.http.toString()}/${widget.addressSuffix}'),
                            subtitle: Text(address.interfaceName),
                          ))
                      .toList(),
                )),
    );
  }

  Icon _getAddressIcon(String interfaceName) {
    if (interfaceName.contains(
        RegExp('Wi-Fi|wifi|wi_fi', caseSensitive: false, multiLine: false))) {
      return const Icon(Icons.wifi, color: Colors.grey);
    }

    return const Icon(Icons.settings_ethernet, color: Colors.grey);
  }

  void _fetchAddresses() async {
    final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        includeLoopback: false,
        type: InternetAddressType.IPv4);

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

class ShowcallerAddressModel {
  final Uri http;
  final String interfaceName;

  ShowcallerAddressModel(
    this.http,
    this.interfaceName,
  );
}