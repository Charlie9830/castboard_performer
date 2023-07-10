import 'dart:async';
import 'dart:io';

import 'package:castboard_core/classes/PhotoRef.dart';
import 'package:castboard_core/enums.dart';
import 'package:castboard_core/logging/LoggingManager.dart';
import 'package:castboard_core/models/ActorIndex.dart';
import 'package:castboard_core/models/ActorModel.dart';
import 'package:castboard_core/models/ActorRef.dart';
import 'package:castboard_core/models/CastChangeModel.dart';
import 'package:castboard_core/models/ManifestModel.dart';
import 'package:castboard_core/models/PresetModel.dart';
import 'package:castboard_core/models/RemoteShowData.dart';
import 'package:castboard_core/models/ShowDataModel.dart';
import 'package:castboard_core/models/SlideSizeModel.dart';
import 'package:castboard_core/models/TrackIndex.dart';
import 'package:castboard_core/models/TrackModel.dart';
import 'package:castboard_core/models/SlideModel.dart';
import 'package:castboard_core/models/TrackRef.dart';
import 'package:castboard_core/models/performerDeviceModel.dart';
import 'package:castboard_core/models/playback_state_model.dart';
import 'package:castboard_core/models/subtitle_field_model.dart';
import 'package:castboard_core/models/system_controller/SystemConfig.dart';
import 'package:castboard_core/models/understudy/font_manifest.dart';
import 'package:castboard_core/models/understudy/slide_model.dart';
import 'package:castboard_core/models/understudy/slides_payload_model.dart';
import 'package:castboard_core/models/understudy/message_model.dart';
import 'package:castboard_core/storage/ImportedShowData.dart';
import 'package:castboard_core/storage/Storage.dart';
import 'package:castboard_core/system-commands/SystemCommands.dart';
import 'package:castboard_core/update_manager/update_check_result.dart';
import 'package:castboard_core/update_manager/update_manager.dart';
import 'package:castboard_core/utils/build_font_list.dart';
import 'package:castboard_core/version/fileVersion.dart';
import 'package:castboard_core/web_renderer/build_background_html.dart';
import 'package:castboard_core/web_renderer/build_slide_elements_html.dart';
import 'package:castboard_performer/update_ready_splash.dart';
import 'package:castboard_performer/update_status_splash.dart';
import 'package:castboard_performer/constants.dart';
import 'package:castboard_performer/defines.dart';
import 'package:castboard_performer/models/understudy_session_model.dart';
import 'package:castboard_performer/no_show_splash.dart';
import 'package:castboard_performer/CriticalError.dart';
import 'package:castboard_performer/LoadingSplash.dart';
import 'package:castboard_core/widgets/Player.dart';
import 'package:castboard_performer/RouteNames.dart';
import 'package:castboard_performer/SlideCycler.dart';
import 'package:castboard_performer/fontLoadingHelpers.dart';
import 'package:castboard_performer/models/ShowFileUploadResult.dart';
import 'package:castboard_performer/scheduleRestart.dart';
import 'package:castboard_performer/server/Server.dart';
import 'package:castboard_performer/service_advertiser/serviceAdvertiser.dart';
import 'package:castboard_performer/settings.dart';
import 'package:castboard_performer/system_controller/SystemConfigCommitResult.dart';
import 'package:castboard_performer/system_controller/SystemController.dart'
    as sc;
import 'package:castboard_performer/window_close.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';
import 'package:collection/collection.dart';

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

  // Window Manager
  try {
    WidgetsFlutterBinding.ensureInitialized();
    // Must add this line.
    await windowManager.ensureInitialized();

    const WindowOptions windowOptions = WindowOptions(
        center: true,
        backgroundColor: Colors.transparent,
        fullScreen: kReleaseMode,
        minimumSize: kMinimumWindowSize,
        size: kMinimumWindowSize,
        title: 'Castboard Performer');

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (e, stacktrace) {
    LoggingManager.instance.player
        .severe('Failed to initialize Window Manager', e, stacktrace);
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
  Map<String, SubtitleFieldModel> _subtitleFields =
      {}; // Not required for normal running of Performer. But stored
  // so it can be carried over into showfiles saved by Performer then exported to designer.

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
  List<SlideModel> _playingSlides = [];

  SlideOrientation _slideOrientation = SlideOrientation.landscape;

  // Playback
  bool _playing = false;
  SlideCycler? _cycler;
  String _currentSlideId = '';
  String _nextSlideId = '';
  Set<String> _disabledSlideIds = {};

  // File Manifest
  ManifestModel _fileManifest = const ManifestModel.blank();

  // Current running configuration.
  SystemConfig _runningConfig = SystemConfig.defaults();

  // Understudy
  Map<String, UnderstudySessionModel> _understudySessions = {};

  // Software Update.
  bool _softwareUpdateReady = false;
  double? _updateDownloadProgress;

  // Non Tracked State
  late final Server _server;
  final Map<String, DateTime> _sessionHeartbeats = {};
  // ignore: unused_field
  late Timer _heartbeatTimer;
  final sc.SystemController _systemController = sc.SystemController();

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
        onUnderstudyClientConnectionEstablished:
            _handleUnderstudyClientConnectionEstablished,
        onUnderstudyClientConnectionDropped:
            _handleUnderstudyClientConnectionDropped);

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
              snackBarTheme: SnackBarThemeData(
                contentTextStyle: const TextStyle(
                  color: Colors.white,
                ),
                backgroundColor: Colors.blueGrey.shade600,
                actionTextColor: Colors.amberAccent.shade700,
              )),
          initialRoute: RouteNames.loadingSplash,
          routes: {
            RouteNames.loadingSplash: (_) => LoadingSplash(
                  status: _startupStatus,
                  criticalError: _criticalError,
                ),
            RouteNames.settings: (context) => Settings(
                  runningConfig: _runningConfig,
                  understudySessions: _understudySessions,
                  onDownloadUpdate: _handleDownloadUpdate,
                  updateDownloadProgress: _updateDownloadProgress,
                  updateReadyToInstall: _softwareUpdateReady,
                  onRunningConfigUpdated: (value) =>
                      _handleRunningConfigUpdated(value, context),
                ),
            RouteNames.player: (_) => Player(
                  noSlides: _playingSlides.isEmpty,
                  currentSlideId: _currentSlideId,
                  nextSlideId:
                      _nextSlideId, // The next slide is 'Offstaged' to force Image Caching TODO: Is this required anymore?
                  slides: _slides,
                  actors: _actors,
                  tracks: _tracks,
                  trackRefsByName: _trackRefsByName,
                  displayedCastChange: _displayedCastChange,
                  actualSlideSize: const SlideSizeModel.defaultSize()
                      .orientated(_slideOrientation)
                      .toSize(),
                  playing: _playing,
                  offstageUpcomingSlides: true,
                  showDemoIndicator: _fileManifest.isDemoShow,
                ),
            RouteNames.noShowSplash: (_) => NoShowSplash(
                  serverPort: _runningConfig.serverPort,
                ),
          },
        ),
      ),
    );
  }

  void _handleKeyboardEvent(RawKeyEvent event) async {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        // Check that state of Navigator.canPop() and only procceed if it's false (ie we are at the root route).
        // It's a bit hacky, but it ensures we can't open up multiple instances of the Settings Route on top of eachother.
        if (navigatorKey.currentState?.canPop() == false) {
          navigatorKey.currentState?.pushNamed(RouteNames.settings);
        }
      }
    }
  }

  void _handleRunningConfigUpdated(
      SystemConfig value, BuildContext context) async {
    final commitResult =
        await _systemController.commitSystemConfig(_runningConfig, value);

    if (commitResult.success == false) {
      LoggingManager.instance.player.warning('Failed to commit System Config');
    }

    setState(() => _runningConfig = value);

    if (commitResult.restartRequired) {
      await showDialog(
          context: context,
          builder: (_) => AlertDialog(
                title: const Text('Settings modified'),
                content: const Text(
                    'Performer needs to be restarted for these changes to take affect'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Okay'),
                  )
                ],
              ));
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

  void _handleDownloadProgressDelegate(int value) {
    if (value == 0) {
      setState(() {
        _updateDownloadProgress = 0.0;
      });
    } else {
      setState(() {
        _updateDownloadProgress = (value / 100).ceilToDouble();
      });
    }
  }

  void _handleDownloadUpdate() async {
    setState(() {
      _updateDownloadProgress = 0.0;
    });

    try {
      final result = await UpdateManager.instance
          .downloadUpdate(onProgress: _handleDownloadProgressDelegate);

      if (result.success) {
        setState(() {
          _updateDownloadProgress = null;
          _softwareUpdateReady = true;
        });
      }
    } catch (e) {
      setState(() {
        _updateDownloadProgress = null;
        _softwareUpdateReady = false;
      });
    }
  }

  Future<PerformerDeviceModel> _handleConnectivityPingReceived() async {
    final showName = _fileManifest.fileName;
    return PerformerDeviceModel.detailsOnly(
      showName: showName,
      deviceId: _runningConfig.deviceId,
      softwareVersion: _runningConfig.playerVersion,
      deviceName: _runningConfig.deviceName,
      port: _runningConfig.serverPort,
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
    // Dump the current route(s) and push the loading splash. This ensures that we don't end up deleting an image file
    // just as an ImageProvider is trying to access it.
    navigatorKey.currentState!
        .popUntil((route) => route.isFirst && route.isCurrent);
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
        navigatorKey.currentState!.popAndPushNamed(RouteNames.noShowSplash);
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
    SystemConfig systemConfig;
    try {
      LoggingManager.instance.player.info('Initializing SystemController');
      await _systemController.initialize();

      LoggingManager.instance.player.info('SystemController Initialized');
      LoggingManager.instance.player.info('Reading System Configuration');
      systemConfig = await _systemController.getSystemConfig();
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
      await _initializeServer(systemConfig.serverPort);
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
      await ServiceAdvertiser.initialize(
        _runningConfig.deviceName,
        _handleConnectivityPingReceived,
        mdnsPort: systemConfig.serverPort,
      );
      LoggingManager.instance.server.info('Service Advertising Initialized');
    } catch (e, stacktrace) {
      LoggingManager.instance.server
          .warning('Failed to initialize discovery service', e, stacktrace);
    }

    // Init Update Manager.
    _updateStartupStatus('Initializing Update Manager');
    try {
      LoggingManager.instance.general.info('Initializing Update Manager');
      await UpdateManager.initialize(
        currentVersion: (await PackageInfo.fromPlatform()).version,
        updateServerAddress: kUpdateServerAddress,
      );

      // Check for Updates in the background.
      _backgroundDownloadSoftwareUpdates();
    } catch (e, stacktrace) {
      LoggingManager.instance.general
          .warning('Failed to initialize UpdateManager', e, stacktrace);
    }

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

        // Check for the Update status and if need be Push the status splash.
        await _checkUpdateStatusAndPushNextNamedRoute();

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
          nextNamedRoute: RouteNames.noShowSplash);
    }
  }

  void _loadShow(ImportedShowData data) async {
    // Dump current Slide Cycler.
    LoggingManager.instance.player.info("Resetting slide cycler");
    if (_cycler != null) {
      _cycler!.dispose();
    }

    final playbackState =
        data.playbackState ?? const PlaybackStateModel.initial();

    // Playback State.
    LoggingManager.instance.player.info("Processing playback state");
    LoggingManager.instance.player.info("Processing presets");
    // Really try not to show a blank Preset. Fallback to the Default Preset if anything is missing.
    String currentPresetId = playbackState.currentPresetId;

    // Coerce Preset Id to default if blank value.
    currentPresetId = currentPresetId == ''
        ? const PresetModel.builtIn().uid
        : currentPresetId;
    final currentPreset =
        data.showData.presets[currentPresetId] ?? const PresetModel.builtIn();

    // Get ancilliary Preset data.
    final combinedPresetIds = playbackState.combinedPresetIds;
    final liveCastChangeEdits = playbackState.liveCastChangeEdits;

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

    // Slides
    LoggingManager.instance.player.info('Processing Slides');
    final playingSlides = _filterAndSortSlides(
        data.slideData.slides,
        playbackState
            .disabledSlideIds); // Stores the slides selected for playback and in correct order.
    final initialSlide = playingSlides.isNotEmpty ? playingSlides.first : null;
    final initialNextSlide =
        playingSlides.length >= 2 ? playingSlides[1] : null;

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
    final backgroundFiles = playingSlides.map(
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

    setState(() {
      _actors = data.showData.actors;
      _actorIndex = data.showData.actorIndex;
      _trackIndex = data.showData.trackIndex;
      _tracks = data.showData.tracks;
      _trackRefsByName = data.showData.trackRefsByName;
      _presets = data.showData.presets;
      _slides = data.slideData.slides;
      _playingSlides = playingSlides;
      _currentSlideId = initialSlide?.uid ?? '';
      _nextSlideId = initialNextSlide?.uid ?? '';
      _cycler = _buildCycler(playingSlides, initialSlide);
      _playing = true;
      _slideOrientation = data.slideData.slideOrientation;
      _currentPresetId = currentPresetId;
      _combinedPresetIds = combinedPresetIds;
      _liveCastChangeEdits = liveCastChangeEdits;
      _displayedCastChange = displayedCastChange;
      _disabledSlideIds = playbackState.disabledSlideIds;
      _fileManifest = data.manifest;
      _subtitleFields = data.showData
          .subtitleFields; // No actually used by performer but stored so it can be carried over
      // into showfiles saved by Performer.
    });

    _updateWebViewerClientHTML(
      playingSlides,
      playingSlides.isEmpty ? -1 : playingSlides.length,
      initialClientConnection:
          true, // Likely a new show, so treat as a full refresh for Understudy.
    );

    LoggingManager.instance.player
        .info("Load show completed. Pushing player route");

    // Push player Route.
    navigatorKey.currentState?.popAndPushNamed(RouteNames.player);
  }

  SlideCycler _buildCycler(
      List<SlideModel> playingSlides, SlideModel? initialSlide) {
    return SlideCycler(
      slides: playingSlides,
      currentSlideIndex: initialSlide != null ? 0 : -1,
      onPlaybackOrSlideChange: _handleSlideCycle,
    );
  }

  Future<void> _backgroundDownloadSoftwareUpdates() async {
    final result = await UpdateManager.instance.checkForUpdates();

    if (result.status == UpdateStatus.readyToDownload) {
      final downloadResult = await UpdateManager.instance
          .downloadUpdate(onProgress: _handleDownloadProgressDelegate);
      if (downloadResult.success == true) {
        setState(() {
          _softwareUpdateReady = true;
          _updateDownloadProgress = null;
        });
      }
    }
  }

  void _resetImageCache(BuildContext context) {
    imageCache.clear();
    imageCache.maximumSizeBytes = 800 * 1000000;
  }

  void _handleSlideCycle(int playingIndex, String currentSlideId,
      String nextSlideId, bool playing) {
    setState(() {
      _currentSlideId = currentSlideId;
      _nextSlideId = nextSlideId;
      _playing = playing;
    });

    _server.setWebViewerClientsSlideIndex(playingIndex);
  }

  Future<void> _initializeServer(int port) async {
    return await _server.initalize(port);
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
      softwareUpdateReady:
          _softwareUpdateReady, // Let Showcaller know if a Performer Software update is ready to install.
      showData: ShowDataModel(
        tracks: _tracks,
        trackRefsByName: <String,
            TrackRef>{}, // Showcaller does not need this data, so no point sending it.
        actorIndex: _actorIndex,
        trackIndex: _trackIndex,
        actors: _actors,
        presets: _presets,
        subtitleFields: _subtitleFields,
      ),
      playbackState: PlaybackStateModel(
        combinedPresetIds: _combinedPresetIds,
        currentPresetId: _currentPresetId,
        liveCastChangeEdits: _liveCastChangeEdits,
        disabledSlideIds: _disabledSlideIds,
        slidesMetadata:
            _slides.values.map((slide) => slide.toMetadata()).toList(),
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

    final playingSlides =
        _filterAndSortSlides(_slides, data.playbackState.disabledSlideIds);

    Set<String>? newDisabledSlideIds;
    SlideCycler? newCycler;
    String? currentSlideId;
    String? nextSlideId;

    // If some Slides have been disabled or enabled. We need to do extra work with the Slide Cycler.
    if (setEquals(_disabledSlideIds, data.playbackState.disabledSlideIds) !=
        true) {
      newDisabledSlideIds = data.playbackState.disabledSlideIds;

      // Clear the Slide Cycler and rebuild it with the new state of Playing slides.
      _cycler?.dispose();

      final initialSlide = playingSlides.firstOrNull;
      final nextSlide = playingSlides.length >= 2 ? playingSlides[1] : null;

      newCycler = _buildCycler(playingSlides, playingSlides.firstOrNull);

      currentSlideId = initialSlide?.uid ?? '';
      nextSlideId = nextSlide?.uid ?? '';
    }

    setState(() {
      _cycler = newCycler ?? _cycler;
      _currentSlideId = currentSlideId ?? _currentSlideId;
      _nextSlideId = nextSlideId ?? _nextSlideId;
      _disabledSlideIds = newDisabledSlideIds ?? _disabledSlideIds;
      _playingSlides = playingSlides;
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
          subtitleFields: _subtitleFields,
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

    _updateWebViewerClientHTML(_playingSlides, _getCurrentSlideIndex());

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
    final result = await _systemController.commitSystemConfig(
        _runningConfig, incomingConfigDelta);

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

  Future<void> _checkUpdateStatusAndPushNextNamedRoute(
      {String? nextNamedRoute}) async {
    if (await UpdateManager.instance.didJustUpdate() == true) {
      // Clean up leftover Update files.
      UpdateManager.instance.cleanupFiles();

      // Show the Update Success Splash.
      setState(() {
        _softwareUpdateReady = true;
      });
      await navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => const UpdateStatusSplash(
                success: true,
                holdDuration: Duration(seconds: 14),
              )));

      // Push to next route.
      if (mounted && nextNamedRoute != null) {
        navigatorKey.currentState?.popAndPushNamed(nextNamedRoute);
      }
      return;
    }

    if ((await UpdateManager.instance.checkForUpdates()).status ==
            UpdateStatus.readyToInstall &&
        mounted) {
      // Show the Update Ready to Install Splash.
      await navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) => const UpdateReadySplash(
                holdDuration: Duration(seconds: 8),
              )));

      // Push to next route.
      if (mounted && nextNamedRoute != null) {
        navigatorKey.currentState?.popAndPushNamed(nextNamedRoute);
      }
      return;
    }

    if (nextNamedRoute != null && mounted) {
      navigatorKey.currentState?.popAndPushNamed(nextNamedRoute);
    }
  }

  void _handleUnderstudyClientConnectionEstablished(
      UnderstudySessionModel session) {
    _updateWebViewerClientHTML(_playingSlides, _getCurrentSlideIndex(),
        initialClientConnection: true);

    setState(() {
      _understudySessions =
          Map<String, UnderstudySessionModel>.from(_understudySessions
            ..addAll({
              session.id: session,
            }));
    });
  }

  void _handleUnderstudyClientConnectionDropped(String clientId) {
    if (_understudySessions.containsKey(clientId) == false) {
      return;
    }

    setState(() {
      _understudySessions = Map<String, UnderstudySessionModel>.from(
          _understudySessions
            ..update(clientId, (session) => session.copyWith(active: false)));
    });
  }

  Future<void> _updateWebViewerClientHTML(
      List<SlideModel> playingSlides, int currentIndex,
      {bool initialClientConnection = false}) async {
    if (_fileManifest == const ManifestModel.blank()) {
      // No Show Loaded.
      _server.updateWebViewerClientHTML(UnderstudyMessageModel(
          type: UnderstudyMessageType.noShow, payload: ''));

      return;
    }

    final slidesPayload = await _buildSlidesPayload(
        _slides, playingSlides, currentIndex,
        initialClientConnection: initialClientConnection);

    _server.updateWebViewerClientHTML(UnderstudyMessageModel(
        type: initialClientConnection
            ? UnderstudyMessageType.initialPayload
            : UnderstudyMessageType.contentChange,
        payload: slidesPayload.toJson()));
  }

  Future<UnderstudySlidesPayloadModel> _buildSlidesPayload(
      Map<String, SlideModel> allSlides,
      List<SlideModel> playingSlides,
      int currentIndex,
      {bool initialClientConnection = false}) async {
    final slideAssetsUrlPrefix = kDebugMode
        ? 'http://localhost:${_server.port}/api/understudy'
        : '/api/understudy';

    final slideSize =
        const SlideSizeModel.defaultSize().orientated(_slideOrientation);

    return UnderstudySlidesPayloadModel(
        fontManifest: UnderstudyFontManifest.fromList(
          urlPrefix: slideAssetsUrlPrefix,
          requiredFontFamilies: buildFontList(_slides.values.toList()),
          customFonts: _fileManifest.requiredFonts,
        ),
        headshotSourcePaths:
            _extractDisplayedHeadshotSourcePaths(slideAssetsUrlPrefix),
        backgroundSourcePaths:
            _extractBackgroundSourcePaths(slideAssetsUrlPrefix),
        imageSourcePaths: initialClientConnection
            ? await _extractImageSourcePaths(slideAssetsUrlPrefix)
            : [],
        currentSlideIndex: currentIndex,
        width: slideSize.width,
        height: slideSize.height,
        slides: playingSlides.map((slide) {
          final slideElement = buildSlideElementsHtml(
            urlPrefix: slideAssetsUrlPrefix,
            slide: slide,
            actors: _actors,
            castChange: _displayedCastChange,
            trackRefsByName: _trackRefsByName,
            tracks: _tracks,
            showDemoDisclaimer: _fileManifest.isDemoShow,
          );

          final backgroundElement = buildBackgroundHtml(
              urlPrefix: slideAssetsUrlPrefix,
              slides: allSlides,
              slideId: slide.uid,
              slideSize: slideSize.toSize());

          slideElement.append(backgroundElement);

          return UnderstudySlideModel(
              holdTime: slide.holdTime, html: slideElement.outerHtml);
        }).toList());
  }

  List<String> _extractDisplayedHeadshotSourcePaths(String assetsUrlPrefix) {
    final displayedActorRefs = _displayedCastChange.assignments.values;
    return displayedActorRefs
        .map((actorRef) => _actors[actorRef]?.headshotRef)
        .whereType<ImageRef>()
        .where((imageRef) => imageRef != const ImageRef.none())
        .map((imageRef) => '$assetsUrlPrefix/headshots/${imageRef.basename}')
        .toList();
  }

  List<String> _extractBackgroundSourcePaths(String assetsUrlPrefix) {
    return _slides.values
        .map((slide) => slide.backgroundRef)
        .where((ref) => ref != const ImageRef.none())
        .map((ref) => '$assetsUrlPrefix/backgrounds/${ref.basename}')
        .toList();
  }

  Future<List<String>> _extractImageSourcePaths(String assetsUrlPrefix) async {
    // Trying to extract image files from the slides collection will be painful and probably an 0n operation.
    // So instead we just bug the Storage interface to give us a list of the image file basenames from the image
    // storage directory.

    final imageNames = await Storage.instance.listImageFileNames();

    return imageNames.map((name) => '$assetsUrlPrefix/images/$name').toList();
  }

  List<SlideModel> _filterAndSortSlides(
      Map<String, SlideModel> slideCollection, Set<String> disabledSlideIds) {
    return slideCollection.values
        .where((slide) => disabledSlideIds.contains(slide.uid) == false)
        .toList()
      ..sort((a, b) => a.index - b.index);
  }

  int _getCurrentSlideIndex() {
    return _playingSlides.indexWhere((slide) => slide.uid == _currentSlideId);
  }

  @override
  void dispose() {
    _server.shutdown();
    super.dispose();
  }
}
