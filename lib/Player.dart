import 'package:castboard_core/elements/backgroundBuilder.dart';
import 'package:castboard_core/elements/elementBuilders.dart';
import 'package:castboard_core/layout-canvas/LayoutCanvas.dart';
import 'package:castboard_core/models/ActorModel.dart';
import 'package:castboard_core/models/ActorRef.dart';
import 'package:castboard_core/models/PresetModel.dart';
import 'package:castboard_core/models/TrackModel.dart';
import 'package:castboard_core/models/SlideModel.dart';
import 'package:castboard_core/models/TrackRef.dart';
import 'package:castboard_core/slide-viewport/SlideViewport.dart';
import 'package:flutter/material.dart';

class Player extends StatelessWidget {
  final Map<String, SlideModel> slides;
  final Map<TrackRef, TrackModel> tracks;
  final Map<ActorRef, ActorModel> actors;
  final PresetModel currentPreset;
  final String currentSlideId;
  final int width;
  final int height;
  final double renderScale;

  const Player({
    Key key,
    this.slides,
    this.tracks,
    this.actors,
    this.currentPreset,
    this.currentSlideId,
    this.width = 1920,
    this.height = 1080,
    this.renderScale = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (slides[currentSlideId] == null) {
      return Container(child: Text('Current Slide is Null'));
    }

    return Container(
        child: SlideViewport(
      enableScrolling: false,
      renderScale: renderScale,
      background: getBackground(
        slides,
        currentSlideId,
      ),
      width: width,
      height: height,
      child: LayoutCanvas(
        interactive: false,
        elements: buildElements(
          slide: slides[currentSlideId],
          actors: actors,
          tracks: tracks,
          castChange: currentPreset?.castChange,
        ),
        renderScale: renderScale,
      ),
    ));
  }
}
