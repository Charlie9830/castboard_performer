import 'dart:async';

import 'package:castboard_core/models/SlideModel.dart';

typedef void OnSlideChangeCallback(String slideId, bool playing);

class SlideCycler {
  final List<SlideModel> slides;
  final OnSlideChangeCallback onSlideChange;
  bool playing = true;
  SlideModel currentSlide;
  Timer timer;

  SlideCycler({this.slides, this.onSlideChange}) {
    if (slides.isNotEmpty) {
      currentSlide = slides.first;
    }

    play();
  }

  void play() {
    if (currentSlide != null) {
      playing = true;
      final holdDuration =
          Duration(seconds: currentSlide.holdTime.floor().toInt());
      timer = Timer(holdDuration, () => _cycle());
    }
  }

  void pause() {
    playing = false;
    timer?.cancel();
  }

  void stepForward() {
    playing = false;
    currentSlide = _getNextSlide();
    _notifyListeners(currentSlide, playing);
  }

  void stepBack() {
    playing = false;
    currentSlide = _getPrevSlide();
    _notifyListeners(currentSlide, playing);
  }

  void _cycle() {
    if (playing) {
      final newSlide = _getNextSlide();
      final holdDuration =
          Duration(seconds: currentSlide.holdTime.floor().toInt());

      currentSlide = newSlide;
      timer = Timer(holdDuration, () => _cycle());
      _notifyListeners(currentSlide, playing);
    }
  }

  SlideModel _getNextSlide() {
    if (currentSlide == null && slides.isEmpty) {
      return null;
    }

    if (slides.length == 1) {
      return currentSlide;
    }

    if (currentSlide.index == slides.length - 1) {
      return slides.first;
    } else {
      return slides[currentSlide.index + 1];
    }
  }

  SlideModel _getPrevSlide() {
    if (currentSlide == null && slides.isEmpty) {
      return null;
    }

    if (slides.length == 1) {
      return currentSlide;
    }

    if (currentSlide.index == 0) {
      return slides.last;
    } else {
      return slides[currentSlide.index - 1];
    }
  }

  void _notifyListeners(SlideModel currentSlide, bool playing) {
    onSlideChange?.call(currentSlide?.uid ?? '', playing);
  }

  void dispose() {
    timer?.cancel();
  }
}
