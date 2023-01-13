import 'package:castboard_performer/versionCodename.dart';
import 'package:flutter/material.dart';

class UpdateStatusSplash extends StatefulWidget {
  final bool success;
  final Duration holdDuration;
  
  const UpdateStatusSplash(
      {Key? key, this.success = true, required this.holdDuration})
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
        child: widget.success ? const _Success() : const _Fail(),
      ),
    );
  }

  Future<void> _startHoldTimer(BuildContext context, Duration duration) async {
    await Future.delayed(duration);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class _Success extends StatelessWidget {
  const _Success({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.all(24),
          child: Icon(Icons.check_circle, color: Colors.green, size: 64),
        ),
        Text('Update complete', style: Theme.of(context).textTheme.headline5),
                const SizedBox(height: 16),
        Text('Performer will resume in a few seconds',
            style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 32),
        Text('Version codename', style: Theme.of(context).textTheme.bodySmall),
        const Text(kVersionCodename)
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
        const Padding(
          padding: EdgeInsets.all(24),
          child: Icon(Icons.sentiment_neutral, color: Colors.yellow, size: 64),
        ),
        Text('Update was not successful',
            style: Theme.of(context).textTheme.headline5),
        Text('Please try again', style: Theme.of(context).textTheme.headline5),
        const SizedBox(height: 16),
        Text('Version codename', style: Theme.of(context).textTheme.caption),
        const Text(kVersionCodename)
      ],
    );
  }
}
