import 'package:flutter/material.dart';

class FadePageTransition extends StatefulWidget {
  final Widget child;

  const FadePageTransition({Key? key, required this.child}) : super(key: key);

  @override
  FadePageTransitionState createState() => FadePageTransitionState();
}

class FadePageTransitionState extends State<FadePageTransition>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _animation = Tween(begin: 0.0, end: 1.0).animate(_controller);

    _controller.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _animation, child: widget.child);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
