import 'dart:async';

import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/models/SlideModel.dart';

typedef OnSlideChangeCallback = void Function(
    int playingIndex, String slideId, String nextSlideId, bool playing);

class SlideCycler {
  final List<SlideModel> slides;
  final OnSlideChangeCallback onPlaybackOrSlideChange;

  late bool _playing = true;
  int currentSlideIndex;
  Timer? _timer;

  SlideCycler({
    required this.slides,
    this.currentSlideIndex = -1,
    required this.onPlaybackOrSlideChange,
  }) {
    _playing = currentSlideIndex != -1;

    play();
  }

  SlideModel? tryFetchSlideAtIndex(int index) {
    if (index == -1 || index > slides.length) {
      return null;
    }

    return slides[index];
  }

  void play() {
    final currentSlide = tryFetchSlideAtIndex(currentSlideIndex);
    if (currentSlide == null) {
      return;
    }

    _playing = true;

    final holdDuration =
        Duration(seconds: currentSlide.holdTime.floor().toInt());

    if (_timer != null && _timer!.isActive) {
      _timer!.cancel();
    }

    _timer = Timer(holdDuration, () => _cycle());

    _notifyListeners(currentSlideIndex, currentSlide,
        tryFetchSlideAtIndex(_getNextSlideIndex(currentSlideIndex)), true);
  }

  void pause() {
    _playing = false;
    _timer?.cancel();
    _notifyListeners(currentSlideIndex, tryFetchSlideAtIndex(currentSlideIndex),
        tryFetchSlideAtIndex(_getNextSlideIndex(currentSlideIndex)), false);
  }

  void stepForward() {
    final newCurrentSlideIndex = _getNextSlideIndex(currentSlideIndex);
    final newCurrentSlide = tryFetchSlideAtIndex(newCurrentSlideIndex);
    final newNextSlide = tryFetchSlideAtIndex(_getNextSlideIndex(
        newCurrentSlideIndex)); // Call getNextSlideIndex to grab the slide after next.

    _playing = false;
    currentSlideIndex = newCurrentSlideIndex;
    _notifyListeners(
        newCurrentSlideIndex, newCurrentSlide, newNextSlide, _playing);
  }

  void stepBack() {
    final newCurrentSlideIndex = _getPrevSlideIndex(currentSlideIndex);
    final newCurrentSlide = tryFetchSlideAtIndex(newCurrentSlideIndex);

    _playing = false;
    currentSlideIndex = newCurrentSlideIndex;
    // Because we are stepping backwards, there isn't much point in provided a 'next' slide
    // as it the user could step forward or back again anyway.
    _notifyListeners(newCurrentSlideIndex, newCurrentSlide, null, _playing);
  }

  void _cycle() {
    if (_playing) {
      final nextSlideIndex = _getNextSlideIndex(currentSlideIndex);
      final nextSlide = tryFetchSlideAtIndex(nextSlideIndex);

      if (nextSlide == null) {
        print('*** WARNING **** nextSlide was null in _cycle()');
        LoggingManager.instance.player
            .warning('nextSlide was null in SlideCycler._cycle()');
        return;
      }

      currentSlideIndex = nextSlideIndex;

      // Set Timer to hold duration.
      final holdDuration =
          Duration(seconds: nextSlide.holdTime.floor().toInt());

      if (_timer != null) {
        _timer!.cancel();
      }
      _timer = Timer(holdDuration, () => _cycle());

      _notifyListeners(currentSlideIndex, nextSlide,
          tryFetchSlideAtIndex(_getNextSlideIndex(nextSlideIndex)), _playing);
    }
  }

  int _getNextSlideIndex(int currentIndex) {
    if (slides.isEmpty) {
      return -1;
    }

    if (slides.length == 1) {
      return 0;
    }

    if (currentIndex == slides.length - 1) {
      // Wrap back to start.
      return 0;
    }

    if (currentIndex >= slides.length) {
      // Wrap back to Start, But make a note. probably shouldnt happen.
      LoggingManager.instance.player.warning(
          'Out of range slide index detected at _getNextSlideIndex. Current Index: $currentIndex. Collection Length ${slides.length}');
      print(
          '***** Warning ******* Out of Range index provided to _getNextSlideIndex');
      return 0;
    }

    // Step Forward.
    return currentIndex + 1;
  }

  int _getPrevSlideIndex(int currentIndex) {
    if (slides.isEmpty) {
      return -1;
    }

    if (slides.length == 1) {
      return 0;
    }

    if (currentIndex == 0) {
      // Wrap around to the End.
      return slides.length - 1;
    }

    if (currentIndex < 0 || currentIndex >= slides.length) {
      // Wrap around to the End, but make a note. Probably shouldn't happen.
      LoggingManager.instance.player.warning(
          'Out of range slide index detected at _getNextPrevIndex. Current Index: $currentIndex. Collection Length ${slides.length}');
      print(
          '***** Warning ******* Out of Range index provided to _getPrevSlideIndex');
      return slides.length - 1;
    }

    // Step backward.
    return currentIndex - 1;
  }

  void _notifyListeners(int playingIndex, SlideModel? currentSlide,
      SlideModel? nextSlide, bool playing) {
    if (currentSlide != null) {
      onPlaybackOrSlideChange.call(
          playingIndex, currentSlide.uid, nextSlide?.uid ?? '', playing);
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
