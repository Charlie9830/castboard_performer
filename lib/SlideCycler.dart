import 'dart:async';

import 'package:castboard_core/models/SlideModel.dart';

typedef void OnSlideChangeCallback(
    String slideId, String nextSlideId, bool playing);

class SlideCycler {
  final List<SlideModel> slides;
  final OnSlideChangeCallback onPlaybackOrSlideChange;

  late bool _playing = true;
  late SlideModel? _currentSlide;
  Timer? _timer;

  SlideCycler({
    required this.slides,
    SlideModel? initialSlide,
    required this.onPlaybackOrSlideChange,
  }) {
    _currentSlide = initialSlide;
    _playing = initialSlide != null;

    play();
  }

  void play() {
    if (_currentSlide == null) {
      return;
    }

    _playing = true;
    final holdDuration =
        Duration(seconds: _currentSlide!.holdTime.floor().toInt());

    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }

    _timer = Timer(holdDuration, () => _cycle());

    _notifyListeners(_currentSlide, _getNextSlide(_currentSlide), true);
  }

  void pause() {
    _playing = false;
    _timer?.cancel();
    _notifyListeners(_currentSlide, _getNextSlide(_currentSlide), false);
  }

  void stepForward() {
    final newCurrentSlide = _getNextSlide(_currentSlide);
    final newNextSlide = _getNextSlide(newCurrentSlide);

    _playing = false;
    _currentSlide = newCurrentSlide;
    _notifyListeners(newCurrentSlide, newNextSlide, _playing);
  }

  void stepBack() {
    final newCurrentSlide = _getPrevSlide(_currentSlide);
    final newPrevSlide = _getPrevSlide(newCurrentSlide);

    _playing = false;
    _currentSlide = newCurrentSlide;
    _notifyListeners(newCurrentSlide, newPrevSlide, _playing);
  }

  void _cycle() {
    if (_playing) {
      final newSlide = _getNextSlide(_currentSlide)!;
      final holdDuration =
          Duration(seconds: _currentSlide!.holdTime.floor().toInt());

      _currentSlide = newSlide;
      _timer = Timer(holdDuration, () => _cycle());
      _notifyListeners(_currentSlide, _getNextSlide(_currentSlide), _playing);
    }
  }

  SlideModel? _getNextSlide(SlideModel? current) {
    if (current == null && slides.isEmpty) {
      return null;
    }

    if (slides.length == 1) {
      return current;
    }

    if (current!.index == slides.length - 1) {
      return slides.first;
    } else {
      return slides[current.index + 1];
    }
  }

  SlideModel? _getPrevSlide(SlideModel? current) {
    if (current == null && slides.isEmpty) {
      return null;
    }

    if (slides.length == 1) {
      return current;
    }

    if (current!.index == 0) {
      return slides.last;
    } else {
      return slides[current.index - 1];
    }
  }

  void _notifyListeners(
      SlideModel? currentSlide, SlideModel? nextSlide, bool playing) {
    if (currentSlide != null) {
      onPlaybackOrSlideChange.call(currentSlide.uid, nextSlide?.uid ?? '', playing);
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
