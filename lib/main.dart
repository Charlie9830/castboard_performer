import 'dart:async';
import 'dart:io';

import 'package:castboard_core/enums.dart';
import 'package:castboard_core/image_compressor/image_compressor.dart';
import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/models/ActorIndex.dart';
import 'package:castboard_core/models/ActorModel.dart';
import 'package:castboard_core/models/ActorRef.dart';
import 'package:castboard_core/models/CastChangeModel.dart';
import 'package:castboard_core/models/ManifestModel.dart';
import 'package:castboard_core/models/PresetModel.dart';
import 'package:castboard_core/models/RemoteCastChangeData.dart';
import 'package:castboard_core/models/RemoteShowData.dart';
import 'package:castboard_core/models/ShowDataModel.dart';
import 'package:castboard_core/models/SlideSizeModel.dart';
import 'package:castboard_core/models/TrackIndex.dart';
import 'package:castboard_core/models/TrackModel.dart';
import 'package:castboard_core/models/SlideModel.dart';
import 'package:castboard_core/models/TrackRef.dart';
import 'package:castboard_core/models/performerDeviceModel.dart';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_core/models/web_viewer/html_slide_model.dart';
import 'package:castboard_core/models/web_viewer/message_model.dart';
import 'package:castboard_core/models/web_viewer/slides_payload_model.dart';
import 'package:castboard_core/models/web_viewer/web_viewer_font_manifest.dart';
import 'package:castboard_core/storage/ImportedShowData.dart';
import 'package:castboard_core/storage/Storage.dart';
import 'package:castboard_core/system-commands/SystemCommands.dart';
import 'package:castboard_core/utils/build_font_list.dart';
import 'package:castboard_core/version/fileVersion.dart';
import 'package:castboard_core/web_renderer/build_background_html.dart';
import 'package:castboard_core/web_renderer/build_slide_elements_html.dart';
import 'package:castboard_performer/ConfigViewer.dart';
import 'package:castboard_performer/CriticalError.dart';
import 'package:castboard_performer/LoadingSplash.dart';
import 'package:castboard_core/widgets/Player.dart';
import 'package:castboard_performer/RouteNames.dart';
import 'package:castboard_performer/SlideCycler.dart';
import 'package:castboard_performer/UpdateStatusSplash.dart';
import 'package:castboard_performer/fontLoadingHelpers.dart';
import 'package:castboard_performer/models/ShowFileUploadResult.dart';
import 'package:castboard_performer/scheduleRestart.dart';
import 'package:castboard_performer/server/Server.dart';
import 'package:castboard_performer/service_advertiser/serviceAdvertiser.dart';
import 'package:castboard_performer/settings.dart';
import 'package:castboard_performer/system_controller/SystemConfigCommitResult.dart';
import 'package:castboard_performer/system_controller/SystemController.dart';
import 'package:castboard_performer/window_close.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey renderBoundaryKey = GlobalKey();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  String criticalError = '';

  try {
    await _initLogging();
    print('Logging Initialized');
  } catch (error, stacktrace) {
    criticalError = "$error\n$stacktrace";
    stderr.write('Failed to initialize LoggingManager. ${error.toString()}');
    print(criticalError);
  }

  try {
    runApp(AppRoot(
      criticalError: criticalError,
    ));
  } catch (e, stacktrace) {
    print('Uncaught exception in runApp(). $e \n ${stacktrace.toString()}');
    LoggingManager.instance.general
        .severe('Uncaught Exception: ', e, stacktrace);
  }
}

Future<void> _initLogging() async {
  await LoggingManager.initialize('castboard_performer_runtime_logs',
      runAsRelease: true);
  LoggingManager.instance.general.info('\n \n *********************** \n \n');
  LoggingManager.instance.general.info('LoggingManager initialized.');
  LoggingManager.instance.general.info('Application started');
  return;
}

class AppRoot extends StatefulWidget {
  final String criticalError;

  const AppRoot({Key? key, this.criticalError = ''}) : super(key: key);

  @override
  _AppRootState createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  String _startupStatus = 'Starting Up';
  bool _criticalError = false;
  Map<ActorRef, ActorModel> _actors = {};
  List<ActorIndexBase> _actorIndex = <ActorIndexBase>[];
  List<TrackIndexBase> _trackIndex = <TrackIndexBase>[];
  Map<TrackRef, TrackModel> _tracks = {};
  Map<String, TrackRef> _trackRefsByName = {};

  // Presets and Cast Changes
  Map<String, PresetModel> _presets = {};
  CastChangeModel _liveCastChangeEdits = const CastChangeModel.initial();
  String _currentPresetId = '';
  List<String> _combinedPresetIds = const <String>[];

  /// Represents the final fully composed Cast Change, composed from
  /// [_currentPresetId], [_combinedPresetIds] and [_liveCastChangeEdits].
  CastChangeModel _displayedCastChange = const CastChangeModel.initial();

  // Slides
  Map<String, SlideModel> _slides = {};
  SlideOrientation _slideOrientation = SlideOrientation.landscape;

  // Playback
  bool _playing = false;
  SlideCycler? _cycler;
  String _currentSlideId = '';
  String _nextSlideId = '';

  // File Manifest
  ManifestModel _fileManifest = ManifestModel();

  // Current running configuration.
  SystemConfig _runningConfig = SystemConfig.defaults();

  // Non Tracked State
  late final Server _server;
  final Map<String, DateTime> _sessionHeartbeats = {};
  late Timer _heartbeatTimer;
  final SystemController _systemController = SystemController();

  // Focus
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    if (widget.criticalError.isNotEmpty) {
      super.initState();
      return;
    }

    LoggingManager.instance.player.info('Initializing Player state');
    super.initState();

    _server = Server(
        onHeartbeatReceived: _handleHeartbeatReceived,
        onPlaybackCommand: _handlePlaybackCommand,
        onShowFileReceived: _handleShowfileReceived,
        onPrepareShowfileDownload: _handlePrepareShowfileDownloadRequest,
        onShowDataPull: _handleShowDataPull,
        onShowDataReceived: _handleShowDataReceived,
        onSystemCommandReceived: _handleSystemCommandReceived,
        onSystemConfigPull: _handleSystemConfigPull,
        onSystemConfigPostCallback: _handleSystemConfigPost,
        onPrepareLogsDownloadCallback: _handlePrepareLogsDownloadRequest,
        onSoftwareUpdate: _handleSoftwareUpdate,
        onWebViewerClientConnectionEstablished:
            _handleSlideShowClientConnectionEstablished);

    _heartbeatTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _checkHeartbeats(30));

    _initializePerformer();

    registerWindowCloseHook(
      server: _server,
      systemController: _systemController,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.criticalError.isNotEmpty) {
      return CriticalError(errorMessage: widget.criticalError);
    }

    return RepaintBoundary(
      key: renderBoundaryKey,
      child: RawKeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKey: _handleKeyboardEvent,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Castboard Player',
          theme: ThemeData(
            fontFamily: 'Poppins',
            brightness: Brightness.dark,
            primarySwatch: Colors.orange,
          ),
          initialRoute: RouteNames.loadingSplash,
          routes: {
            RouteNames.loadingSplash: (_) => LoadingSplash(
                  status: _startupStatus,
                  criticalError: _criticalError,
                ),
            RouteNames.settings: (_) => Settings(
                  serverPortNumber: kServerPort,
                  onOpenButtonPressed: () {},
                ),
            RouteNames.player: (_) => Player(
                  currentSlideId: _currentSlideId,
                  nextSlideId:
                      _nextSlideId, // The next slide is 'Offstaged' to force Image Caching TODO: Is this required anymore?
                  slides: _slides,
                  actors: _actors,
                  tracks: _tracks,
                  trackRefsByName: _trackRefsByName,
                  displayedCastChange: _displayedCastChange,
                  slideSize: const SlideSizeModel.defaultSize()
                      .orientated(_slideOrientation),

                  slideOrientation: _slideOrientation,
                  playing: _playing,
                  offstageUpcomingSlides: true,
                ),
            RouteNames.configViewer: (_) => const ConfigViewer(),
          },
        ),
      ),
    );
  }

  void _handleKeyboardEvent(RawKeyEvent event) async {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        navigatorKey.currentState?.pushNamed(RouteNames.settings);
      }
    }
  }

  void _checkHeartbeats(int cutOffSeconds) {
    final cutOffTime =
        DateTime.now().subtract(Duration(seconds: cutOffSeconds));

    _sessionHeartbeats
        .removeWhere((id, lastThump) => lastThump.isBefore(cutOffTime));

    // If there are no more active sessions and if we are paused and if we have slides to play and the cycler is active, then
    // Restart the slide show.. Oh and also if the playShowOnIdle Config property is true.
    if (_sessionHeartbeats.isEmpty &&
        _playing == false &&
        _runningConfig.playShowOnIdle == true &&
        _slides.isNotEmpty &&
        _cycler != null) {
      LoggingManager.instance.player
          .info('No more heartbeats, resuming slideshow');
      _cycler!.play();
    }
  }

  Future<PerformerDeviceModel> _handleConnectivityPingReceived() async {
    final systemConfig = await SystemController().getSystemConfig();
    final showName = _fileManifest.fileName;

    return PerformerDeviceModel.detailsOnly(
      showName: showName,
      deviceName: systemConfig.deviceName ?? '',
      softwareVersion: systemConfig.playerVersion,
    );
  }

  void _handleHeartbeatReceived(String sessionId) {
    // Store the session Id in the heartbeats register.
    _sessionHeartbeats.update(sessionId, (_) => DateTime.now(), ifAbsent: () {
      LoggingManager.instance.player
          .info('Received first heartbeat from $sessionId');
      return DateTime.now();
    });
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

  Future<File> _handlePrepareShowfileDownloadRequest() async {
    final file = await Storage.instance.archiveActiveShowForExport();

    return file;
  }

  Future<ShowfileUploadResult> _handleShowfileReceived(List<int> bytes) async {
    // Dump the current route and push the loading splash. This ensures that we don't end up deleting an image file
    // just as an ImageProvider is trying to access it.
    navigatorKey.currentState!.popAndPushNamed(RouteNames.loadingSplash);

    // Validate the incoming show file.
    final validationResult =
        await Storage.instance.validateShowfile(bytes, kMaxAllowedFileVersion);
    if (validationResult.isValid == false) {
      // File is invalid. Log it based on the reason then attempt to return back to the player route if we can.
      if (validationResult.isCompatiableFileVersion == true) {
        LoggingManager.instance.general
            .warning('Invalid showfile received. Rejecting request.');
      }

      if (validationResult.isCompatiableFileVersion == false) {
        LoggingManager.instance.general
            .warning("Incompatiable showfile recieved. Rejecting request");
      }

      final canReturnToSlideShow =
          await Storage.instance.isPerformerStoragePopulated();
      if (canReturnToSlideShow) {
        navigatorKey.currentState!.popAndPushNamed(RouteNames.player);
      } else {
        navigatorKey.currentState!.popAndPushNamed(RouteNames.configViewer);
      }
      return ShowfileUploadResult(
          validationResult: validationResult, generalResult: false);
    }

    // Read the incoming show.
    try {
      final showdata = await Storage.instance.loadArchivedShowfile(bytes);

      // Load into state.
      _loadShow(showdata);

      return ShowfileUploadResult.good(validationResult.manifest);
    } catch (e, stacktrace) {
      LoggingManager.instance.general
          .severe('Failed to load uploaded show into storage.', e, stacktrace);

      return ShowfileUploadResult(generalResult: false, validationResult: null);
    }
  }

  void _postCriticalError(String status) {
    setState(() {
      _criticalError = true;
      _startupStatus = status;
    });
  }

  void _updateStartupStatus(String status) {
    setState(() {
      _startupStatus = status;
    });
  }

  void _initializePerformer() async {
    // Initialize the Storage backend.
    _updateStartupStatus('Initializing internal storage');
    try {
      LoggingManager.instance.player.info('Initializing storage');
      await Storage.initialize(StorageMode.performer);
      LoggingManager.instance.player.info("Storage initialization success");
    } catch (e, stacktrace) {
      LoggingManager.instance.player
          .severe("Storage initialization failed", e, stacktrace);

      _postCriticalError(
          'An error occurred. The Storage module failed to start.');
      return;
    }

    // Init SystemController
    _updateStartupStatus('Initializing System Controller');
    try {
      LoggingManager.instance.player.info('Initializing SystemController');
      await _systemController.initialize();

      LoggingManager.instance.player.info('SystemController Initialized');
      LoggingManager.instance.player.info('Reading System Configuration');
      final systemConfig = await _systemController.getSystemConfig();
      _loadSystemConfig(systemConfig);
    } catch (e, stacktrace) {
      LoggingManager.instance.player.severe(
          "SystemController initialization failed, ${e.toString} \n ${stacktrace.toString()}",
          e,
          stacktrace);

      _postCriticalError(
          'An error occurred. The SystemController failed to start.');
      return;
    }

    _updateStartupStatus('Initializing administration server');
    // Init Server.
    try {
      LoggingManager.instance.player.info('Initializing Server');
      await _initializeServer();
      LoggingManager.instance.player.info('Server initialization success');
    } catch (e, stacktrace) {
      LoggingManager.instance.player
          .severe("Server initialization failed", e, stacktrace);

      _postCriticalError('An error occurred. The Server failed to start.');
      return;
    }

    // Init Advertising Service.
    _updateStartupStatus('Initializing Service Advertising.');
    try {
      LoggingManager.instance.server.info('Initializing Service Advertising');
      final deviceName =
          (await _systemController.getSystemConfig()).deviceName ??
              SystemConfig.defaults().deviceName!;
      await ServiceAdvertiser.initialize(
          _handleConnectivityPingReceived, deviceName);
      LoggingManager.instance.server.info('Service Advertising Initialized');
    } catch (e, stacktrace) {
      LoggingManager.instance.server
          .warning('Failed to initialize discovery service', e, stacktrace);
    }

    print('Service Discovery Running');

    LoggingManager.instance.player
        .info("Searching for previously loaded show file");
    _updateStartupStatus('Looking for previously loaded show file');
    if (await Storage.instance.isPerformerStoragePopulated()) {
      try {
        LoggingManager.instance.player
            .info("Show file located, starting show file read");
        _updateStartupStatus("Opening show file");
        final ImportedShowData data =
            await Storage.instance.loadShowData(allowMigration: true);
        LoggingManager.instance.player
            .info("Show file read complete. Loading into state");

        _updateStartupStatus('Loading show file');
        await _pauseForEffect();

        // Pause for effect a bit further incase we need to read the splash debug info.
        _updateStartupStatus('Stretching...');
        await _pauseForEffect(seconds: 2);
        _updateStartupStatus('Running to mic checks...');
        await _pauseForEffect(seconds: 2);
        _loadShow(data);

        LoggingManager.instance.player.info("Show file loaded into state");
      } catch (e, stacktrace) {
        LoggingManager.instance.player
            .severe("Show file read failed", e, stacktrace);

        _postCriticalError('An error occurred. The Show file failed to load');
      }
    } else {
      // Pause for effect a bit further incase we need to read the splash debug info.
      _updateStartupStatus('Finishing vocal warmups...');
      await _pauseForEffect(seconds: 2);
      _updateStartupStatus('Adjusting wig cap...');
      await _pauseForEffect();

      await _pauseForEffect(seconds: 2);
      LoggingManager.instance.player
          .info('No existing show file found. Proceeding to config route');
      await _checkUpdateStatusAndPushNextNamedRoute(
          nextNamedRoute: RouteNames.configViewer);
    }
  }

  void _loadShow(ImportedShowData data) async {
    // Dump current Slide Cycler.
    LoggingManager.instance.player.info("Reseting slide cycler");
    if (_cycler != null) {
      _cycler!.dispose();
    }

    // Slides
    LoggingManager.instance.player.info('Sorting slides');
    final sortedSlides = List<SlideModel>.from(data.slideData.slides.values)
      ..sort((a, b) => a.index - b.index);
    final initialSlide = sortedSlides.isNotEmpty ? sortedSlides.first : null;
    final initialNextSlide = sortedSlides.length >= 2 ? sortedSlides[1] : null;

    // Image Cache.
    LoggingManager.instance.player.info("Resetting image cache");
    _resetImageCache(context);

    // Pre Cache Backgrounds (Avoids Slides snapping to White or background color during transition).
    // We don't do this for headshots as we render each slide Offstage before showing it, this progressively adds all the
    // headshots into the cache.
    // If we wanted to preCache the headshots, we would have to either preCache every headshot, which isn't efficent as we
    // are rarely displaying every headshot, otherwise we would have to analyze each slide and compare it against the cast change
    // to preCache the images we are going to need, as well as managing a system for evicting unused images from the cache.
    LoggingManager.instance.player.info("Pre caching backgrounds");
    final backgroundFiles = sortedSlides.map(
        (slide) => Storage.instance.getBackgroundFile(slide.backgroundRef));
    final preCacheImageRequests = backgroundFiles
        .where((file) => file != null)
        .map((file) => precacheImage(FileImage(file!), context));

    try {
      await Future.wait(preCacheImageRequests);
      LoggingManager.instance.player.info("Background pre cache complete");
    } catch (e, stacktrace) {
      LoggingManager.instance.player.warning(
          "Some or all backgrounds could not be precached", e, stacktrace);
    }

    // Custom Fonts
    try {
      LoggingManager.instance.player.info("Loading custom fonts");
      final unloadedFontIds =
          await loadCustomFonts(data.manifest.requiredFonts);
      if (unloadedFontIds.isNotEmpty) {
        LoggingManager.instance.player.warning(
            "${unloadedFontIds.length} fonts failed to load, IDs => $unloadedFontIds");
      } else {
        LoggingManager.instance.player.info("Fonts loaded successfully");
      }
    } catch (e, stacktrace) {
      LoggingManager.instance.player
          .severe("An error occured loading fonts", e, stacktrace);
    }

    // Playback State.
    LoggingManager.instance.player.info("Processing playback state");
    LoggingManager.instance.player.info("Processing presets");
    // Really try not to show a blank Preset. Fallback to the Default Preset if anything is missing.
    String currentPresetId =
        data.playbackState?.currentPresetId ?? const PresetModel.builtIn().uid;
    currentPresetId = currentPresetId == ''
        ? const PresetModel.builtIn().uid
        : currentPresetId;
    final currentPreset =
        data.showData.presets[currentPresetId] ?? const PresetModel.builtIn();

    // Get ancilliary Preset data.
    final combinedPresetIds = data.playbackState?.combinedPresetIds ?? const [];
    final liveCastChangeEdits = data.playbackState?.liveCastChangeEdits ??
        const CastChangeModel.initial();

    // Compose the displayed Cast Change.
    LoggingManager.instance.player.info("Composing the displayed cast change");
    final displayedCastChange = CastChangeModel.compose(
      base: currentPreset.castChange,
      combined: combinedPresetIds
          .map((id) =>
              data.showData.presets[id]?.castChange ??
              const CastChangeModel.initial())
          .toList(),
      liveEdits: liveCastChangeEdits,
    );

    // TODO: It's possible that the user could upload an empty showfile. In which case stuff like
    // initialSlide will be null and cause a crash. We need to have handling for an empty showfile.

    setState(() {
      _actors = data.showData.actors;
      _actorIndex = data.showData.actorIndex;
      _trackIndex = data.showData.trackIndex;
      _tracks = data.showData.tracks;
      _trackRefsByName = data.showData.trackRefsByName;
      _presets = data.showData.presets;
      _slides = data.slideData.slides;
      _currentSlideId = initialSlide?.uid ?? _currentSlideId;
      _nextSlideId = initialNextSlide?.uid ?? '';
      _cycler = SlideCycler(
          slides: sortedSlides,
          initialSlide: initialSlide!,
          onPlaybackOrSlideChange: _handleSlideCycle);
      _playing = true;
      _slideOrientation = data.slideData.slideOrientation;
      _currentPresetId = currentPresetId;
      _combinedPresetIds = combinedPresetIds;
      _liveCastChangeEdits = liveCastChangeEdits;
      _displayedCastChange = displayedCastChange;
      _fileManifest = data.manifest;
    });

    _updateWebViewerClientHTML();

    LoggingManager.instance.player
        .info("Load show completed. Pushing player route");

    await _checkUpdateStatusAndPushNextNamedRoute(
        nextNamedRoute: RouteNames.player);
  }

  void _resetImageCache(BuildContext context) {
    imageCache.clear();
    imageCache.maximumSizeBytes = 800 * 1000000;
  }

  void _handleSlideCycle(
      String currentSlideId, String nextSlideId, bool playing) {
    setState(() {
      _currentSlideId = currentSlideId;
      _nextSlideId = nextSlideId;
      _playing = playing;
    });

    _server.setWebViewerClientsSlideIndex(
        _slides.keys.toList().indexOf(currentSlideId));
  }

  Future<void> _initializeServer() async {
    return await _server.initalize();
  }

  void _handleSystemCommandReceived(SystemCommand command) {
    switch (command.type) {
      case SystemCommandType.reboot:
        print('reboot');
        _systemController.reboot();
        break;
      case SystemCommandType.powerOff:
        _systemController.powerOff();
        print('poweroff');
        break;
      case SystemCommandType.restartApplication:
        _systemController.restart();
        print('restart app');
        break;
      default:
        break;
    }
  }

  RemoteShowData _handleShowDataPull() {
    LoggingManager.instance.player
        .info("Show Data Pull requested from remote. Packaging show data...");
    return RemoteShowData(
      showData: ShowDataModel(
        tracks: _tracks,
        trackRefsByName: <String,
            TrackRef>{}, // Showcaller does not need this data, so no point sending it.
        actorIndex: _actorIndex,
        trackIndex: _trackIndex,
        actors: _actors,
        presets: _presets,
      ),
      playbackState: PlaybackStateData(
        combinedPresetIds: _combinedPresetIds,
        currentPresetId: _currentPresetId,
        liveCastChangeEdits: _liveCastChangeEdits,
      ),
      manifest: _fileManifest,
    );
  }

  Future<bool> _handleShowDataReceived(RemoteShowData data) async {
    LoggingManager.instance.player.info("Show Data received from remote.");
    // Process and push to State.
    // Presets.
    LoggingManager.instance.player.info("Processing preset data");
    final presets = _updatePresets(data, _presets);
    LoggingManager.instance.player.info('Pushing to state');
    setState(() {
      _presets = presets;
      _currentPresetId = data.playbackState.currentPresetId;
      _combinedPresetIds = data.playbackState.combinedPresetIds;
      _liveCastChangeEdits = data.playbackState.liveCastChangeEdits;
      _displayedCastChange = CastChangeModel.compose(
          base: presets[data.playbackState.currentPresetId]?.castChange,
          combined: data.playbackState.combinedPresetIds
              .map((id) =>
                  presets[id]?.castChange ?? const CastChangeModel.initial())
              .toList(),
          liveEdits: data.playbackState.liveCastChangeEdits);
    });

    // Update Permanent Storage.
    try {
      LoggingManager.instance.player.info("Updating permanent storage");
      await Storage.instance.updatePerformerShowData(
        // Provide the existing values we have in state to ShowDataModel except for Presets, as presets are
        // the only thing that showcaller actually modifies.
        showData: ShowDataModel(
          actors: _actors,
          actorIndex: _actorIndex,
          trackIndex: _trackIndex,
          tracks: _tracks,
          presets: presets, // Only Presets have actually changed.
          trackRefsByName: _trackRefsByName,
        ),
        playbackState: data.playbackState,
      );

      LoggingManager.instance.player
          .info('Permanent storage updated successfully');
    } catch (e, stacktrace) {
      LoggingManager.instance.player.warning(
          'An Error occured whilst updating permanent storage', e, stacktrace);
      return false;
    }

    _updateWebViewerClientHTML();

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

  Future<void> _pauseForEffect({int seconds = 5}) async {
    if (Platform.isLinux && kDebugMode == false) {
      await Future.delayed(Duration(seconds: seconds));
      return;
    } else {
      return;
    }
  }

  Future<SystemConfig?> _handleSystemConfigPull() async {
    final SystemConfig? config;

    try {
      config = await _systemController.getSystemConfig();
    } catch (e, stacktrace) {
      LoggingManager.instance.systemManager.warning(
          'An exception was thrown whilst retrieving the system config.',
          e,
          stacktrace);

      return null;
    }

    try {
      // Append the PackageInfo.
      final info = await PackageInfo.fromPlatform();
      return config.copyWith(
        playerVersion: info.version,
        playerBuildNumber: info.buildNumber,
        playerBuildSignature: info.buildSignature,
      );
    } catch (e) {
      LoggingManager.instance.general.severe('PackageInfo threw an exception');
      return null;
    }
  }

  Future<SystemConfigCommitResult> _handleSystemConfigPost(
      SystemConfig incomingConfigDelta) async {
    // incomingConfig in this context will only represent what the user wants to change. All properties are Nullable.
    // TODO: Maybe split this into another type like maybe SystemConfigDelta.

    // Pass the incomingConfig onto the SystemController to commit to the system. It will return a result dictating
    // if it was successfull, if a restart is requried and the resulting configuration.
    final result =
        await _systemController.commitSystemConfig(incomingConfigDelta);

    if (result.success == false) {
      // Something wen't wrong. Pass it back to the server to inform the user.
      return result;
    }

    if (result.restartRequired) {
      // Schedule a restart for a few seconds in the future. This will give time for the Server to send a response back to the remote informing it that a
      // restart is imminent.
      scheduleRestart(const Duration(seconds: 5), _systemController);
      return result;
    } else {
      // No Restart required. Push the new running Config to state and return execution back to the server.
      _loadSystemConfig(result.resultingConfig);
      return result;
    }
  }

  void _loadSystemConfig(SystemConfig config) {
    setState(() {
      _runningConfig = config;
    });
  }

  Future<File> _handlePrepareLogsDownloadRequest() async {
    LoggingManager.instance.general.info('Exporting Log Files');
    final file = await LoggingManager.instance.exportLogs();

    return file;
  }

  Future<bool> _handleSoftwareUpdate(List<int> byteData) {
    return _systemController.updateApplication(byteData);
  }

  Future<void> _checkUpdateStatusAndPushNextNamedRoute({
    required String nextNamedRoute,
  }) async {
    final updateStatus = await _systemController.getUpdateStatus();
    if (updateStatus != UpdateStatus.none) {
      // Reset the updateStatus flag if it is set to success.
      if (updateStatus == UpdateStatus.success) {
        await _systemController.resetUpdateStatus();
      }

      // Now show a status splash that will update the user of the finished state
      // of the update.
      await _showUpdateStatusSplash(updateStatus);
    }

    // Push the correct route based on the value of showLoaded.
    navigatorKey.currentState?.popAndPushNamed(nextNamedRoute);
  }

  Future<void> _showUpdateStatusSplash(UpdateStatus status) async {
    // Push the UpdateStatusSplash to the Navigator.
    // It will automatically pop itself of after the given duration.
    await navigatorKey.currentState!.push(MaterialPageRoute(
      builder: (_) => UpdateStatusSplash(
        success: status == UpdateStatus.success,
        holdDuration: const Duration(seconds: 8),
      ),
      fullscreenDialog: true,
      maintainState: false,
    ));

    return;
  }

  void _handleSlideShowClientConnectionEstablished() {
    _updateWebViewerClientHTML();
  }

  void _updateWebViewerClientHTML() {
    print('Sending');
    _server.updateWebViewerClientHTML(MessageModel(
        type: MessageType.payload, payload: _buildSlidesPayload().toJson()));
  }

  SlidesPayloadModel _buildSlidesPayload() {
    final slideAssetsUrlPrefix = kDebugMode
        ? 'http://${_server.address.address}:${_server.port}/api/slideshow'
        : '/api/slideshow';

    return SlidesPayloadModel(
        fontManifest: WebViewerFontManifest.fromList(
          urlPrefix: slideAssetsUrlPrefix,
          requiredFontFamilies: buildFontList(_slides.values.toList()),
          customFonts: _fileManifest.requiredFonts,
        ),
        currentSlideIndex: _slides.keys.toList().indexOf(_currentSlideId),
        slides: _slides.values.map((slide) {
          final slideElement = buildSlideElementsHtml(
            urlPrefix: slideAssetsUrlPrefix,
            slide: slide,
            actors: _actors,
            castChange: _displayedCastChange,
            trackRefsByName: _trackRefsByName,
            tracks: _tracks,
          );

          final backgroundElement = buildBackgroundHtml(
              urlPrefix: slideAssetsUrlPrefix,
              slides: _slides,
              slideId: slide.uid,
              slideSize: const SlideSizeModel.defaultSize()
                  .orientated(_slideOrientation)
                  .toSize());

          slideElement.append(backgroundElement);

          return HTMLSlideModel(
              holdTime: slide.holdTime, html: slideElement.outerHtml);
        }).toList());
  }

  @override
  void dispose() {
    _server.shutdown();
    super.dispose();
  }
}
