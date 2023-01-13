import 'package:castboard_core/update_manager/update_manager.dart';
import 'package:castboard_performer/versionCodename.dart';
import 'package:flutter/material.dart';

class UpdateReadySplash extends StatefulWidget {
  final Duration holdDuration;

  const UpdateReadySplash({Key? key, required this.holdDuration})
      : super(key: key);

  @override
  State<UpdateReadySplash> createState() => _UpdateReadySplashState();
}

class _UpdateReadySplashState extends State<UpdateReadySplash> {
  @override
  void initState() {
    _startHoldTimer(context, widget.holdDuration);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.update, size: 36),
          const SizedBox(height: 16),
          Text(
              'A software update is ready to install.',
              style: Theme.of(context).textTheme.bodyMedium),
          Text(' Click below to begin installation now, or you can begin the installation from Showcaller later.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => UpdateManager.instance.executeUpdate(),
            child: const Text('Install'),
          ),
          const SizedBox(height: 96),
          Text('Performer will resume shortly',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
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
