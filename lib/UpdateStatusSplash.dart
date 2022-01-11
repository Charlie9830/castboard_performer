import 'package:castboard_performer/versionCodename.dart';
import 'package:flutter/material.dart';

class UpdateStatusSplash extends StatefulWidget {
  final bool success;
  final Duration holdDuration;
  const UpdateStatusSplash(
      {Key? key,
      this.success = true,
      this.holdDuration = const Duration(seconds: 5)})
      : super(key: key);

  @override
  State<UpdateStatusSplash> createState() => _UpdateStatusSplashState();
}

class _UpdateStatusSplashState extends State<UpdateStatusSplash> {
  @override
  void initState() {
    _startHoldTimer(context, widget.holdDuration);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        child: widget.success ? _Success() : _Fail(),
      ),
    );
  }

  Future<void> _startHoldTimer(BuildContext context, Duration duration) async {
    await Future.delayed(duration);

    Navigator.of(context).pop();
  }
}

class _Success extends StatelessWidget {
  const _Success({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Icon(Icons.check_circle, color: Colors.green, size: 64),
        ),
        Text('Update complete', style: Theme.of(context).textTheme.headline5),
        Text('Player will resume in a few seconds',
            style: Theme.of(context).textTheme.headline5),
        SizedBox(height: 16),
        Text('Version codename', style: Theme.of(context).textTheme.caption),
        Text('$kVersionCodename')
      ],
    );
  }
}

class _Fail extends StatelessWidget {
  const _Fail({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Icon(Icons.sentiment_neutral, color: Colors.green, size: 64),
        ),
        Text('Update was not successful',
            style: Theme.of(context).textTheme.headline5),
        Text('Please try again', style: Theme.of(context).textTheme.headline5),
        SizedBox(height: 16),
        Text('Version codename', style: Theme.of(context).textTheme.caption),
        Text('$kVersionCodename')
      ],
    );
  }
}
