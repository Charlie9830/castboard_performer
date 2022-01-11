import 'package:flutter/material.dart';

class ApplicationTitle extends StatelessWidget {
  const ApplicationTitle({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text('Castboard', style: Theme.of(context).textTheme.headline2);
  }
}
