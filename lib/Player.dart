import 'package:castboard_core/elements/backgroundBuilder.dart';
import 'package:castboard_core/elements/elementBuilders.dart';
import 'package:castboard_core/layout-canvas/LayoutCanvas.dart';
import 'package:castboard_core/models/ActorModel.dart';
import 'package:castboard_core/models/PresetModel.dart';
import 'package:castboard_core/models/TrackModel.dart';
import 'package:castboard_core/models/SlideModel.dart';
import 'package:castboard_core/slide-viewport/SlideViewport.dart';
import 'package:flutter/material.dart';

class Player extends StatelessWidget {
  final Map<String, SlideModel> slides;
  final Map<String, TrackModel> tracks;
  final Map<String, ActorModel> actors;
  final PresetModel currentPreset;
  final String currentSlideId;

  const Player(
      {Key key,
      this.slides,
      this.tracks,
      this.actors,
      this.currentPreset,
      this.currentSlideId})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (slides[currentSlideId] == null) {
      return Container(child: Text('Current Slide is Null'));
    }

    return Container(
        child: SlideViewport(
      enableScrolling: false,
      renderScale: 1,
      background: getBackground(
        slides,
        currentSlideId,
      ),
      width: 1280,
      height: 720,
      child: LayoutCanvas(
        interactive: false,
        elements: buildElements(
          slide: slides[currentSlideId],
          actors: actors,
          preset: currentPreset,
          tracks: tracks,
        ),
        renderScale: 1,
      ),
    ));
  }
}
