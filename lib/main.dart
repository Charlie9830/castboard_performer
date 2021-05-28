import 'package:castboard_core/classes/StandardSlideSizes.dart';
import 'package:castboard_core/enums.dart';
import 'package:castboard_core/font-loading/FontLoadCandidate.dart';
import 'package:castboard_core/font-loading/FontLoading.dart';
import 'package:castboard_core/font-loading/FontLoadingResult.dart';
import 'package:castboard_core/models/ActorModel.dart';
import 'package:castboard_core/models/ActorRef.dart';
import 'package:castboard_core/models/FontModel.dart';
import 'package:castboard_core/models/PresetModel.dart';
import 'package:castboard_core/models/SlideSizeModel.dart';
import 'package:castboard_core/models/TrackModel.dart';
import 'package:castboard_core/models/SlideModel.dart';
import 'package:castboard_core/models/TrackRef.dart';
import 'package:castboard_core/storage/ImportedShowData.dart';
import 'package:castboard_core/storage/Storage.dart';
import 'package:castboard_player/ConfigViewer.dart';
import 'package:castboard_player/LoadingSplash.dart';
import 'package:castboard_player/Player.dart';
import 'package:castboard_player/RouteNames.dart';
import 'package:castboard_player/SlideCycler.dart';
import 'package:castboard_player/fontLoadingHelpers.dart';
import 'package:castboard_player/server/Server.dart';
import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(AppRoot());
}

Server server;

class AppRoot extends StatefulWidget {
  AppRoot({Key key}) : super(key: key);

  @override
  _AppRootState createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  Map<ActorRef, ActorModel> _actors;
  Map<TrackRef, TrackModel> _tracks;
  Map<String, PresetModel> _presets;
  Map<String, SlideModel> _slides;
  SlideSizeModel _slideSize = StandardSlideSizes.defaultSize;
  SlideOrientation _slideOrientation = SlideOrientation.landscape;

  List<FontModel> _unloadedFonts = const <FontModel>[];
  SlideCycler _cycler;
  PresetModel _currentPreset;
  String _currentSlideId = '';

  Server _server;

  @override
  void initState() {
    super.initState();

    _server = Server(
      address: '0.0.0.0',
      port: 8080,
      onPlaybackCommand: _handlePlaybackCommand,
      onShowFileReceived: _handleShowFileReceived,
    );

    _initalizePlayer();
  }

  @override
  Widget build(BuildContext context) {
    final windowSize = _getWindowSize(context);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Castboard Player',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.grey,
      ),
      initialRoute: RouteNames.loadingSplash,
      routes: {
        RouteNames.loadingSplash: (_) => LoadingSplash(),
        RouteNames.player: (_) => Player(
              currentSlideId: _currentSlideId,
              slides: _slides,
              actors: _actors,
              tracks: _tracks,
              currentPreset: _currentPreset,
              width: windowSize.width.toInt(),
              height: windowSize.height.toInt(),
              renderScale: _getRenderScale(windowSize,
                  _getDesiredSlideSize(_slideSize, _slideOrientation)),
            ),
        RouteNames.configViewer: (_) => ConfigViewer(),
      },
    );
  }

  Size _getDesiredSlideSize(
      SlideSizeModel slideSize, SlideOrientation orientation) {
    return slideSize?.orientated(orientation)?.toSize() ??
        StandardSlideSizes.defaultSize.toSize();
  }

  Size _getWindowSize(BuildContext context) {
    return MediaQuery.of(context).size;
  }

  double _getRenderScale(Size windowSize, Size desiredSlideSize) {
    final xRatio = windowSize.width / desiredSlideSize.width;
    final yRatio = windowSize.height / desiredSlideSize.height;

    final xRatioDiff = xRatio - 1;
    final yRatioDiff = yRatio - 1;

    if (xRatioDiff > yRatioDiff) {
      return xRatio;
    } else {
      return yRatio;
    }
  }

  void _handlePlaybackCommand(PlaybackCommand command) {
    if (_cycler != null) {
      switch (command) {
        case PlaybackCommand.play:
          _cycler.play();
          break;
        case PlaybackCommand.pause:
          _cycler.pause();
          break;
        case PlaybackCommand.next:
          _cycler.stepForward();
          break;
        case PlaybackCommand.prev:
          _cycler.stepBack();
          break;
      }
    }
  }

  void _handleShowFileReceived() async {
    final data = await Storage.instance.readFromPlayerStorage();

    _loadShow(data);
  }

  void _initalizePlayer() async {
    // Init Storage
    await Storage.initalize(StorageMode.player);

    // Init Server.
    await _initializeServer();

    if (await Storage.instance.isPlayerStoragePopulated()) {
      final ImportedShowData data =
          await Storage.instance.readFromPlayerStorage();

      _loadShow(data);
    } else {
      navigatorKey.currentState?.pushNamed(RouteNames.configViewer);
    }
  }

  void _loadShow(ImportedShowData data) async {
    if (_cycler != null) {
      _cycler.dispose();
    }

    final sortedSlides = List<SlideModel>.from(data.slides.values)
      ..sort((a, b) => a.index - b.index);

    final initialSlide = sortedSlides.isNotEmpty ? sortedSlides.first : null;

    final currentPreset = data.presets.isNotEmpty
        ? data.presets[PresetModel.builtIn().uid]
        : PresetModel.builtIn();

    final unloadedFontIds = await loadCustomFonts(data.manifest.requiredFonts);
    final fontsLookup = Map<String, FontModel>.fromEntries(
        data.manifest.requiredFonts.map((font) => MapEntry(font.uid, font)));

    setState(() {
      _actors = data.actors;
      _tracks = data.tracks;
      _presets = data.presets;
      _slides = data.slides;
      _currentSlideId = initialSlide?.uid ?? _currentSlideId;
      _unloadedFonts = unloadedFontIds.map((id) => fontsLookup[id]).toList();
      _cycler = SlideCycler(
          slides: sortedSlides,
          initialSlide: initialSlide,
          onSlideChange: _handleSlideCycle);
      _currentPreset = currentPreset;
      _slideSize = StandardSlideSizes.all[data.slideSizeId] ??
          StandardSlideSizes.defaultSize;
      _slideOrientation = data.slideOrientation ?? SlideOrientation.landscape;
    });

    navigatorKey.currentState?.pushNamed(RouteNames.player);
  }

  void _handleSlideCycle(String slideId, bool playing) {
    setState(() {
      _currentSlideId = slideId;
    });
  }

  Future<void> _initializeServer() async {
    if (_server != null) {
      await _server.initalize();
      print('Server Ready');
    }
  }

  @override
  void dispose() {
    if (_server != null) {
      _server.shutdown();
    }
    super.dispose();
  }
}
