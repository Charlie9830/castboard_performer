import 'package:castboard_core/classes/StandardSlideSizes.dart';
import 'package:castboard_core/enums.dart';
import 'package:castboard_core/models/ActorModel.dart';
import 'package:castboard_core/models/ActorRef.dart';
import 'package:castboard_core/models/CastChangeModel.dart';
import 'package:castboard_core/models/FontModel.dart';
import 'package:castboard_core/models/PresetModel.dart';
import 'package:castboard_core/models/RemoteCastChangeData.dart';
import 'package:castboard_core/models/RemoteShowData.dart';
import 'package:castboard_core/models/ShowDataModel.dart';
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

Server? server;

class AppRoot extends StatefulWidget {
  AppRoot({Key? key}) : super(key: key);

  @override
  _AppRootState createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  String _startupStatus = 'Starting Up';
  Map<ActorRef, ActorModel> _actors = {};
  Map<TrackRef, TrackModel> _tracks = {};

  // Presets and Cast Changes
  Map<String, PresetModel> _presets = {};
  CastChangeModel _liveCastChangeEdits = CastChangeModel.initial();
  String _currentPresetId = '';
  List<String> _combinedPresetIds = const <String>[];

  /// Represents the final fully composed Cast Change, composed from
  /// [_currentPresetId], [_combinedPresetIds] and [_liveCastChangeEdits].
  CastChangeModel _displayedCastChange = CastChangeModel.initial();

  // Slides
  Map<String, SlideModel> _slides = {};
  SlideSizeModel _slideSize = StandardSlideSizes.defaultSize;
  SlideOrientation _slideOrientation = SlideOrientation.landscape;

  List<FontModel> _unloadedFonts = const <FontModel>[];
  SlideCycler? _cycler;
  String _currentSlideId = '';

  Server? _server;

  @override
  void initState() {
    super.initState();

    _server = Server(
        address: '0.0.0.0',
        port: 8080,
        onPlaybackCommand: _handlePlaybackCommand,
        onShowFileReceived: _handleShowFileReceived,
        onShowDataPull: _handleShowDataPull,
        onShowDataReceived: _handleShowDataReceived);
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
        RouteNames.loadingSplash: (_) => LoadingSplash(
              status: _startupStatus,
            ),
        RouteNames.player: (_) => Player(
              currentSlideId: _currentSlideId,
              slides: _slides,
              actors: _actors,
              tracks: _tracks,
              displayedCastChange: _displayedCastChange,
              slideSize: _slideSize,
              slideOrientation: _slideOrientation,
            ),
        RouteNames.configViewer: (_) => ConfigViewer(),
      },
    );
  }

  void _handlePlaybackCommand(PlaybackCommand command) {
    if (_cycler != null) {
      switch (command) {
        case PlaybackCommand.play:
          _cycler!.play();
          break;
        case PlaybackCommand.pause:
          _cycler!.pause();
          break;
        case PlaybackCommand.next:
          _cycler!.stepForward();
          break;
        case PlaybackCommand.prev:
          _cycler!.stepBack();
          break;
      }
    }
  }

  void _handleShowFileReceived() async {
    final data = await Storage.instance!.readFromPlayerStorage();

    _loadShow(data);
  }

  void _updateStartupStatus(String status) {
    setState(() {
      _startupStatus = status;
    });
  }

  void _initalizePlayer() async {
    _updateStartupStatus('Initializing internal storage');
    // Init Storage
    await Storage.initalize(StorageMode.player);

    _updateStartupStatus('Initializing administration server');
    // Init Server.
    await _initializeServer();

    _updateStartupStatus('Looking for previously loaded show file');
    if (await Storage.instance!.isPlayerStoragePopulated()) {
      final ImportedShowData data =
          await Storage.instance!.readFromPlayerStorage();

      _updateStartupStatus('Loading show file');
      _loadShow(data);
    } else {
      navigatorKey.currentState?.pushNamed(RouteNames.configViewer);
    }
  }

  void _loadShow(ImportedShowData data) async {
    // Dump current Slide Cycler.
    if (_cycler != null) {
      _cycler!.dispose();
    }

    // Slides
    final sortedSlides = List<SlideModel>.from(data.slides.values)
      ..sort((a, b) => a.index - b.index);
    final initialSlide = sortedSlides.isNotEmpty ? sortedSlides.first : null;

    // Custom Fonts
    final unloadedFontIds = await loadCustomFonts(data.manifest.requiredFonts);
    final fontsLookup = Map<String, FontModel>.fromEntries(
      data.manifest.requiredFonts.map(
        (font) => MapEntry(font.uid, font),
      ),
    );

    // Playback State.
    
    // Really try not to show a blank Preset. Fallback to the Default Preset if anything is missing.
    String currentPresetId =
        data.playbackState?.currentPresetId ?? PresetModel.builtIn().uid;
    currentPresetId =
        currentPresetId == '' ? PresetModel.builtIn().uid : currentPresetId;
    final currentPreset =
        data.presets[currentPresetId] ?? PresetModel.builtIn();

    // Get ancilliary Preset data.
    final combinedPresetIds = data.playbackState?.combinedPresetIds ?? const [];
    final liveCastChangeEdits =
        data.playbackState?.liveCastChangeEdits ?? CastChangeModel.initial();

    // Compose the displayed Cast Change.
    final displayedCastChange = CastChangeModel.compose(
      base: currentPreset.castChange,
      combined: combinedPresetIds
          .map(
              (id) => data.presets[id]?.castChange ?? CastChangeModel.initial())
          .toList(),
      liveEdits: liveCastChangeEdits,
    );

    setState(() {
      _actors = data.actors;
      _tracks = data.tracks;
      _presets = data.presets;
      _slides = data.slides;
      _currentSlideId = initialSlide?.uid ?? _currentSlideId;
      _unloadedFonts = unloadedFontIds.map((id) => fontsLookup[id]!).toList();
      _cycler = SlideCycler(
          slides: sortedSlides,
          initialSlide: initialSlide!,
          onSlideChange: _handleSlideCycle);
      _slideSize = StandardSlideSizes.all[data.slideSizeId] ??
          StandardSlideSizes.defaultSize;
      _slideOrientation = data.slideOrientation;
      _currentPresetId = currentPresetId;
      _combinedPresetIds = combinedPresetIds;
      _liveCastChangeEdits = liveCastChangeEdits;
      _displayedCastChange = displayedCastChange;
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
      return await _server!.initalize();
    }

    return;
  }

  RemoteShowData _handleShowDataPull() {
    return RemoteShowData(
        showData: ShowDataModel(
          tracks: _tracks,
          actors: _actors,
          presets: _presets,
        ),
        playbackState: PlaybackStateData(
          combinedPresetIds: _combinedPresetIds,
          currentPresetId: _currentPresetId,
          liveCastChangeEdits: _liveCastChangeEdits,
        ));
  }

  Future<bool> _handleShowDataReceived(RemoteShowData data) async {
    // Process and push to State.
    // Presets.
    final presets = _updatePresets(data, _presets);
    setState(() {
      _presets = presets;
      _currentPresetId = data.playbackState.currentPresetId;
      _combinedPresetIds = data.playbackState.combinedPresetIds;
      _liveCastChangeEdits = data.playbackState.liveCastChangeEdits;
      _displayedCastChange = CastChangeModel.compose(
          base: presets[data.playbackState.currentPresetId]?.castChange,
          combined: data.playbackState.combinedPresetIds
              .map((id) => presets[id]?.castChange ?? CastChangeModel.initial())
              .toList(),
          liveEdits: data.playbackState.liveCastChangeEdits);
    });

    // Update Permanent Storage.
    try {
      await Storage.instance!.updatePlayerShowData(
          presets: presets, playbackState: data.playbackState);
    } catch (error) {
      return false;
    }

    return true;
  }

  Map<String, PresetModel> _updatePresets(
      RemoteShowData data, Map<String, PresetModel> existing) {
    if (data.showModificationData == null) {
      return existing;
    }

    final editedPresetIds = data.showModificationData!.editedPresetIds;
    final freshPresetIds = data.showModificationData!.freshPresetIds;
    final deletedPresetIds = data.showModificationData!.deletedPresetIds;

    if (editedPresetIds.isEmpty &&
        freshPresetIds.isEmpty &&
        deletedPresetIds.isEmpty) {
      return existing;
    }

    // Will be a map of all presets including new presets but not including deleted presets.
    final incomingPresets = data.showData.presets;

    // Delete any Presets marked to be deleted.
    final trimmedPresets = Map<String, PresetModel>.from(existing)
      ..removeWhere((key, value) => deletedPresetIds.contains(key));

    // Append any new Presets. (Check they actually exist within incomingPresets first)
    final withNewPresets = Map<String, PresetModel>.from(trimmedPresets)
      ..addAll(
        Map<String, PresetModel>.fromEntries(
          freshPresetIds.where((id) => incomingPresets.containsKey(id)).map(
                (id) => MapEntry(id, incomingPresets[id]!),
              ),
        ),
      );

    // Update Presets. (Check they actually exist within incomingPresets first).
    final withUpdatedPresets = Map<String, PresetModel>.from(withNewPresets)
      ..addAll(
        Map<String, PresetModel>.fromEntries(
          editedPresetIds.where((id) => incomingPresets.containsKey(id)).map(
                (id) => MapEntry(id, incomingPresets[id]!),
              ),
        ),
      );

    return withUpdatedPresets;
  }

  @override
  void dispose() {
    if (_server != null) {
      _server!.shutdown();
    }
    super.dispose();
  }
}
