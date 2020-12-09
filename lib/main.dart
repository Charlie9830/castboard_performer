import 'package:castboard_core/models/ActorModel.dart';
import 'package:castboard_core/models/PresetModel.dart';
import 'package:castboard_core/models/RoleModel.dart';
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
  Map<String, RoleModel> _roles;
  Map<String, PresetModel> _presets;
  Map<String, SlideModel> _slides;
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
        accentColor: Colors.amber,
      ),
      initialRoute: RouteNames.loadingSplash,
      routes: {
        RouteNames.loadingSplash: (_) => LoadingSplash(),
        RouteNames.player: (_) => Player(
              currentSlideId: _currentSlideId,
              slides: _slides,
              actors: _actors,
              roles: _roles,
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

    print('Loading');
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

  void _loadShow(ImportedShowData data) {
    if (_cycler != null) {
      _cycler.dispose();
    }

    final sortedSlides = List<SlideModel>.from(data.slides.values)
      ..sort((a, b) => a.index - b.index);

    final initialSlide = sortedSlides.isNotEmpty ? sortedSlides.first : null;

    final currentPreset =
        data.presets.isNotEmpty ? data.presets.values.first : _currentPreset;

    setState(() {
      _actors = data.actors;
      _roles = data.roles;
      _presets = data.presets;
      _slides = data.slides;
      _currentSlideId = initialSlide?.uid ?? _currentSlideId;
      _cycler = SlideCycler(
          slides: sortedSlides,
          initialSlide: initialSlide,
          onSlideChange: _handleSlideCycle);

      _currentPreset = currentPreset;
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
