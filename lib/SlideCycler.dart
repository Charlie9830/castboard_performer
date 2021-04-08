import 'dart:async';

import 'package:castboard_core/models/SlideModel.dart';

typedef void OnSlideChangeCallback(String slideId, bool playing);

class SlideCycler {
  final List<SlideModel> slides;
  final OnSlideChangeCallback onSlideChange;

  bool _playing = true;
  SlideModel _currentSlide;
  Timer _timer;

  SlideCycler({this.slides, SlideModel initialSlide, this.onSlideChange}) {
    _currentSlide = initialSlide;
    _playing = initialSlide != null;

    play();
  }

  void play() {
    if (_currentSlide != null) {
      _playing = true;
      final holdDuration =
          Duration(seconds: _currentSlide.holdTime.floor().toInt());
      _timer = Timer(holdDuration, () => _cycle());
    }
  }

  void pause() {
    _playing = false;
    _timer?.cancel();
  }

  void stepForward() {
    _playing = false;
    _currentSlide = _getNextSlide();
    _notifyListeners(_currentSlide, _playing);
  }

  void stepBack() {
    _playing = false;
    _currentSlide = _getPrevSlide();
    _notifyListeners(_currentSlide, _playing);
  }

  void _cycle() {
    if (_playing) {
      final newSlide = _getNextSlide();
      final holdDuration =
          Duration(seconds: _currentSlide.holdTime.floor().toInt());

      _currentSlide = newSlide;
      _timer = Timer(holdDuration, () => _cycle());
      _notifyListeners(_currentSlide, _playing);
    }
  }

  SlideModel _getNextSlide() {
    if (_currentSlide == null && slides.isEmpty) {
      return null;
    }

    if (slides.length == 1) {
      return _currentSlide;
    }

    if (_currentSlide.index == slides.length - 1) {
      return slides.first;
    } else {
      return slides[_currentSlide.index + 1];
    }
  }

  SlideModel _getPrevSlide() {
    if (_currentSlide == null && slides.isEmpty) {
      return null;
    }

    if (slides.length == 1) {
      return _currentSlide;
    }

    if (_currentSlide.index == 0) {
      return slides.last;
    } else {
      return slides[_currentSlide.index - 1];
    }
  }

  void _notifyListeners(SlideModel currentSlide, bool playing) {
    onSlideChange?.call(currentSlide?.uid ?? '', playing);
  }

  void dispose() {
    _timer?.cancel();
  }
}