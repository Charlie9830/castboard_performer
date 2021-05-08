import 'package:castboard_core/font-loading/FontLoadCandidate.dart';
import 'package:castboard_core/font-loading/FontLoading.dart';
import 'package:castboard_core/font-loading/FontLoadingResult.dart';
import 'package:castboard_core/models/ActorModel.dart';
import 'package:castboard_core/models/FontModel.dart';
import 'package:castboard_core/models/PresetModel.dart';
import 'package:castboard_core/models/TrackModel.dart';
import 'package:castboard_core/models/SlideModel.dart';
import 'package:castboard_core/storage/ImportedShowData.dart';
import 'package:castboard_core/storage/Storage.dart';
import 'package:castboard_player/ConfigViewer.dart';
import 'package:castboard_player/LoadingSplash.dart';
import 'package:castboard_player/Player.dart';
import 'package:castboard_player/RouteNames.dart';
import 'package:castboard_player/SlideCycler.dart';
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
  Map<String, ActorModel> _actors;
  Map<String, TrackModel> _tracks;
  Map<String, PresetModel> _presets;
  Map<String, SlideModel> _slides;
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
            ),
        RouteNames.configViewer: (_) => ConfigViewer(),
      },
    );
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

    final currentPreset =
        data.presets.isNotEmpty ? data.presets.values.first : _currentPreset;

    print(data.manifest.requiredFonts);
    final unloadedFontIds = await _loadCustomFonts(data.manifest.requiredFonts);
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
    });

    navigatorKey.currentState?.pushNamed(RouteNames.player);
  }

  ///
  /// Pulls Custom fonts from storage and loads into the Engine.
  /// Returns a Set of ids representing any Fonts that could not be loaded.
  /// This could be because the Engine rejected them, files were missing, FontModel.ref was invalid or bad.
  Future<Set<String>> _loadCustomFonts(List<FontModel> requiredFonts) async {
    if (requiredFonts == null || requiredFonts.isEmpty) {
      return <String>{};
    }

    final List<FontModel> goodFonts = [];
    final List<FontModel> missingFonts = [];
    final existenceRequests = requiredFonts.map((font) =>
        _fontExistenceDelegate(font).then(
            (exists) => exists ? goodFonts.add(font) : missingFonts.add(font)));

    await Future.wait(existenceRequests);

    final List<FontLoadCandidate> candidates = [];
    final dataLoadRequests = goodFonts.map((font) => Storage.instance
        .getFontFile(font.ref)
        .readAsBytes()
        .then((data) => candidates
            .add(FontLoadCandidate(font.uid, font.familyName, data))));

    await Future.wait(dataLoadRequests);

    final loadingResults = await FontLoading.loadFonts(candidates);
    print('Good Fonts ${goodFonts.length}');
    print('Missing Fonts ${missingFonts.length}');
    print('Unloaded Fonts ${loadingResults.length}');


    return [
      ...loadingResults
          .where((result) => result.loadResult.success == false)
          .map((result) => result.uid),
      ...missingFonts.map((font) => font.uid)
    ].toSet();
  }

  ///
  /// Delegate for checking if a Font File exists. Will return false even if the file object itself is null, thus protecting
  /// any .then() calls from a null exception.
  ///
  Future<bool> _fontExistenceDelegate(FontModel font) async {
    final file = Storage.instance.getFontFile(font.ref);

    if (file == null) {
      return false;
    } else {
      return file.exists();
    }
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
