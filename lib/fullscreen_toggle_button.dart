import 'package:castboard_performer/setFullscreen.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class FullscreenToggleButton extends StatefulWidget {
  final void Function(bool fullscreen)? onPressed;

  // Setting this parameter will put this widget into controlled mode.
  final bool? isFullscreen;

  const FullscreenToggleButton({Key? key, this.onPressed, this.isFullscreen})
      : super(key: key);

  @override
  State<FullscreenToggleButton> createState() => _FullscreenToggleButtonState();
}

class _FullscreenToggleButtonState extends State<FullscreenToggleButton> {
  bool? _isFullscreen;

  @override
  void initState() {
    _fetchFullscreenValue();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final concreteValue = widget.isFullscreen ?? _isFullscreen;
    if (concreteValue == null) {
      return SizedBox.fromSize(size: Size.zero);
    }

    return TextButton.icon(
      onPressed: () => _toggleFullscreen(concreteValue),
      icon: concreteValue
          ? const Icon(Icons.fullscreen_exit)
          : const Icon(Icons.fullscreen),
      label: concreteValue
          ? const Text('Exit Fullscreen')
          : const Text('Enter Fullscreen'),
    );
  }

  void _toggleFullscreen(bool concreteValue) async {
    final targetState = !concreteValue;
    setState(() {
      _isFullscreen = targetState;
    });

    // Notify listeners (if any).
    widget.onPressed?.call(targetState);

    await setFullScreen(targetState);
  }

  void _fetchFullscreenValue() async {
    final value = widget.isFullscreen ?? await windowManager.isFullScreen();

    setState(() {
      _isFullscreen = value;
    });
  }
}
