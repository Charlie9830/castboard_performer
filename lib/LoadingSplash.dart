import 'package:flutter/material.dart';

class LoadingSplash extends StatelessWidget {
  const LoadingSplash({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Center(
          child: CircularProgressIndicator(),
        ));
  }
}
