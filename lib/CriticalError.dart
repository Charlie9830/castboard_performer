import 'package:flutter/material.dart';

class CriticalError extends StatelessWidget {
  final String errorMessage;
  const CriticalError({Key? key, required this.errorMessage}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            body: Center(
      child: Text(errorMessage),
    )));
  }
}
