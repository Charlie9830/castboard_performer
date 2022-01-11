import 'package:flutter/material.dart';

class ApplicationSubtitle extends StatelessWidget {
  const ApplicationSubtitle({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text('Performer', style: Theme.of(context).textTheme.headline5);
  }
}
