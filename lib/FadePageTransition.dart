import 'package:flutter/material.dart';

class FadePageTransition extends StatefulWidget {
  final Widget child;

  FadePageTransition({Key? key, required this.child}) : super(key: key);

  @override
  _FadePageTransitionState createState() => _FadePageTransitionState();
}

class _FadePageTransitionState extends State<FadePageTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );

    _animation = Tween(begin: 0.0, end: 1.0).animate(_controller);

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(child: widget.child, opacity: _animation);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
