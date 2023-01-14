import 'package:castboard_performer/constants.dart';
import 'package:castboard_performer/server/Server.dart';
import 'package:castboard_performer/server/validate_server_port.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NetworkPortSelector extends StatefulWidget {
  final String value;
  final void Function(int value) onChanged;

  const NetworkPortSelector({
    Key? key,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<NetworkPortSelector> createState() => _NetworkPortSelectorState();
}

class _NetworkPortSelectorState extends State<NetworkPortSelector> {
  late TextEditingController _controller;
  String? _errorText;
  bool _canApply = false;

  @override
  void initState() {
    _controller = TextEditingController(text: widget.value);

    _controller.addListener(_handleControllerValueChanged);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 200,
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Port Number'),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9]')), // Only Digits
                  LengthLimitingTextInputFormatter(5),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
                onPressed: _canApply ? _handleApplyButtonPressed : null,
                child: const Text('Apply')),
            const SizedBox(width: 8),
            if (widget.value != kDefaultServerPort.toString())
              TextButton(
                  onPressed: _handleResetToDefault,
                  child: const Text('Reset to Default'))
          ],
        ),
        Text(_errorText ?? '',
            style: Theme.of(context)
                .textTheme
                .caption!
                .copyWith(color: Colors.red)),
        Text(
            'Only adjust the server port if you are experiencing issues with connecting Showcaller or Understudy to Performer.',
            style: Theme.of(context).textTheme.caption),
        Text(
            'On some corporate networks you may experience issues with firewalls blocking certain ports. Try requesting an open port from the IT department and enter that here.',
            style: Theme.of(context).textTheme.caption),
      ],
    );
  }

  void _handleResetToDefault() {
    widget.onChanged(kDefaultServerPort);
    _controller.text = kDefaultServerPort.toString();
  }

  void _handleControllerValueChanged() {
    setState(() {
      _canApply = _controller.text != widget.value;
    });
  }

  void _handleApplyButtonPressed() {
    final value = _controller.text;

    if (isValid(value) == false) {
      // Invalid entry.
      setState(() {
        _errorText =
            'Invalid value, must be between $kLowestPort and $kHightestPort';
      });

      return;
    }

    // Entry valid.
    // Clear any errors.
    setState(() {
      _errorText = null;
    });

    widget.onChanged(int.parse(_controller.text));
  }

  bool isValid(String value) {
    final asInt = int.tryParse(value);

    if (asInt == null) {
      return false;
    }

    return validateServerPort(asInt);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
