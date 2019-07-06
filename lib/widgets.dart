import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:screen/screen.dart';

import './asuna_video_player.dart';

final _logger = Logger('AsunaVideoPlayerWidget');

class VideoPlayPause extends StatefulWidget {
  final AsunaVideoPlayerController controller;
  final bool isFullscreenMode;

  VideoPlayPause(this.controller, {this.isFullscreenMode = false});

  @override
  State<StatefulWidget> createState() => _VideoPlayPauseState();
}

class _VideoPlayPauseState extends State<VideoPlayPause> {
  VoidCallback listener;
  bool isLayoutVisible;
  bool inactive;
  double videoRatio;
  bool isPortrait;
  bool isPortraitVideo;
//  ValueNotifier<List<bool>> showBrightnessOrVolumeNotifier;

  _VideoPlayPauseState() {
    listener = () {
      if (!inactive) {
        if (!controller.value.isPlaying) {
          showControls();
        } else {
//          _logger.info('(AsunaVideoPlayerController) update state ...');
          setState(() {});
        }
      }
    };
  }

  AsunaVideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    _logger.info('VideoPlayPause(${controller.textureId}).initState ...');
    super.initState();
    inactive = false;
    controller.addListener(listener);
    isLayoutVisible = !controller.value.isPlaying;

    // first control brightness, second control volume
//    showBrightnessOrVolumeNotifier = ValueNotifier([false, false]);

//    final Size size = controller.value.size;
//    videoRatio = size != null ? size.width / size.height : 1;
//    controller.setVolume(1.0);
//    controller.play();
  }

  @override
  void deactivate() {
    _logger.info('VideoPlayPause(${controller.textureId}).deactivate ...');
    inactive = true;

    if (controller.isDisposed) {
      return;
    }
    controller.pause();
//    controller.setVolume(0.0);
    controller.removeListener(listener);
    super.deactivate();
  }

  @override
  void dispose() {
    _logger.info('VideoPlayPause(${controller.textureId}).dispose ...');
//    showBrightnessOrVolumeNotifier.dispose();
    super.dispose();
  }

  void play() {
    controller.play();
    /*
    if (isLayoutVisible) {
      Timer.periodic(new Duration(seconds: 1), (timer) {
        setState(() => isLayoutVisible = false);
        timer.cancel();
      });
    }*/
  }

  void pause() {
    controller.pause();
  }

  void showControls() {
    _logger.info('showControls ...');
    setState(() {
      isLayoutVisible = true;
//      showBrightnessOrVolumeNotifier.value = isLayoutVisible;
    });
  }

  void hideControls() {
    _logger.info('hideControls ...');
    setState(() {
      isLayoutVisible = false;
//      showBrightnessOrVolumeNotifier.value = isLayoutVisible;
    });
  }

  final TextStyle _textStyle = const TextStyle(color: Colors.white, fontSize: 12);

  Widget _buildGesture() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      child: Container(
          constraints: BoxConstraints.expand(),
          child: Align(
              alignment: Alignment.center,
              child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio, child: AsunaVideoPlayer(controller)))),
      onDoubleTap: () {
        _logger.info('VideoPlayPause.onDoubleTap ...');
        if (controller.value.isPlaying) {
          controller.pause();
          showControls();
        } else {
          controller.play();
          hideControls();
        }
      },
      onTap: () {
        _logger.info('VideoPlayPause.onTap ...');
        if (!isLayoutVisible) {
          showControls();
          Timer.periodic(new Duration(seconds: 5), (timer) {
            _logger.info(
                'VideoPlayPause.onTap check status ... playing: ${controller.value.isPlaying} isDisposed: ${controller.isDisposed}');
            if (controller.value.isPlaying) {
              if (mounted && !controller.isDisposed) hideControls();
            }
            timer.cancel();
          });
        } else {
          if (controller.value.isPlaying) {
//            hideControls();
          } else {
            controller.play();
          }
          hideControls();
        }
      },
    );
  }

  Widget _buildPlayPauseIndicator() {
//    _logger.info('_buildPlayPauseIndicator: playing status: ${controller.value.isPlaying}');
    return Center(
        child: IgnorePointer(
            child: AnimatedOpacity(
                opacity: controller.value.isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: const Icon(Icons.pause, size: 100.0, color: Colors.white54))));
  }

  List<Widget> _buildPortraitLayout() {
    final position = controller.value.position;
    final duration = controller.value.duration;
    return [
      // top
      // TODO top right function widgets
      Align(alignment: Alignment.topRight, child: SizedBox(height: 24, child: Row())),
      // middle
      _buildPlayPauseIndicator(),
      // bottom
      Align(
          alignment: Alignment.bottomCenter,
          child: Container(
              margin: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                  height: 24,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                    // play/pause button
                    SizedBox(
                        width: 48,
                        child: MaterialButton(
                            onPressed: () => controller.value.isPlaying ? pause() : play(),
                            padding: EdgeInsets.all(4),
                            child: controller.value.isPlaying
                                ? const Icon(Icons.pause, color: Colors.white70)
                                : const Icon(Icons.play_arrow, color: Colors.white70))),
                    // progress indicator
                    Expanded(child: VideoProgressIndicator(controller, allowScrubbing: true)),
                    // video position info
                    Container(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '${position.inMinutes}:${position.inSeconds % 60}/${duration.inMinutes}:${duration.inSeconds % 60}',
                          style: _textStyle,
                        )),
                    // fullscreen button
                    SizedBox(
                        width: 48,
                        child: SizedBox.expand(
                            child: WillPopScope(
                                onWillPop: () {
                                  _logger.info('willPop in portrait, back to portrait');
                                  // back to portrait when tap back
                                  if (MediaQuery.of(context).orientation == Orientation.landscape) {
                                    SystemChrome.setPreferredOrientations([
                                      DeviceOrientation.portraitUp,
                                      DeviceOrientation.portraitDown
                                    ]);
                                    SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
                                  }
                                  return Future.value(true);
                                },
                                child: MaterialButton(
                                    padding: EdgeInsets.all(4),
                                    onPressed: () {
                                      _logger.info(
                                          'isPortraitVideo: $isPortraitVideo, change fullscreen mode...');

                                      if (isPortraitVideo && !widget.isFullscreenMode) {
                                        return Navigator.push(context,
                                            MaterialPageRoute(builder: (_) {
                                          return _FullscreenPlayer(controller: controller);
                                        }));
                                      }

                                      if (widget.isFullscreenMode) {
                                        return Navigator.pop(context);
                                      }

                                      Navigator.push(context, MaterialPageRoute(builder: (_) {
                                        SystemChrome.setPreferredOrientations([
                                          DeviceOrientation.landscapeLeft,
                                          DeviceOrientation.landscapeRight
                                        ]);
                                        SystemChrome.setEnabledSystemUIOverlays([]);
                                        return _FullscreenPlayer(controller: controller);
                                      }));
                                    },
                                    child: const Icon(Icons.fullscreen, color: Colors.white))))),
                  ])))),
    ];
  }

  List<Widget> _buildLandscapeLayout() {
    return [
      // top
      // middle
      _buildPlayPauseIndicator(),
      // bottom
      Align(
          alignment: Alignment.bottomCenter,
          child: Row(children: <Widget>[
            // play/pause button
            SizedBox(
                width: 48,
                child: MaterialButton(
                    onPressed: () => controller.value.isPlaying ? pause() : play(),
                    padding: EdgeInsets.all(4),
                    child: controller.value.isPlaying
                        ? const Icon(Icons.pause, color: Colors.white70)
                        : const Icon(Icons.play_arrow, color: Colors.white70))),
            // progress indicator
            Expanded(child: VideoProgressIndicator(controller, allowScrubbing: true)),
            // fullscreen button
            SizedBox(
                width: 48,
                child: WillPopScope(
                    onWillPop: () {
                      _logger.info('willPop in landscape, back to portrait');
                      // back to portrait when tap back button when in fullscreen mode
                      if (MediaQuery.of(context).orientation == Orientation.landscape) {
                        SystemChrome.setPreferredOrientations(
                            [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
                        SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
                      }
                      return Future.value(true);
                    },
                    child: MaterialButton(
                        onPressed: () {
                          SystemChrome.setPreferredOrientations(
                              [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
                          Navigator.pop(context);
                        },
                        padding: EdgeInsets.all(4),
                        child: const Icon(Icons.fullscreen, color: Colors.white70)))),
          ])),
    ];
  }

  @override
  Widget build(BuildContext context) {
    isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    isPortraitVideo = controller.value.size.width < controller.value.size.height;

//    _logger.info('isPortrait: $isPortrait isPortraitVideo: $isPortraitVideo isFullscreenMode: ${widget.isFullscreenMode}');
    return Stack(
        fit: StackFit.passthrough,
        children: [
          _buildGesture(),
          _VideoControlScrubber(controller: controller, isFullscreen: widget.isFullscreenMode),
          controller.value.isBuffering
              ? const Center(child: const CircularProgressIndicator())
              : const SizedBox(),
        ]..addAll(
            isLayoutVisible
                ? (isPortrait ? _buildPortraitLayout() : _buildLandscapeLayout())
                : [const SizedBox()],
          ));
  }
}

class _VideoIndicatorValue {
  bool showProgressIndicator;
  bool showBrightness;
  bool showVolume;
  Duration currentDuration;
  double currentBrightness;
  double currentVolume;
  DateTime lastProgressOperationAt;
  DateTime lastBrightnessOrVolumeOperationAt;

  _VideoIndicatorValue({
    this.showProgressIndicator = false,
    this.showBrightness = false,
    this.showVolume = false,
    this.currentDuration = const Duration(),
    this.currentBrightness = .0,
    this.currentVolume = .0,
    this.lastProgressOperationAt,
    this.lastBrightnessOrVolumeOperationAt,
  });

  _VideoIndicatorValue copyWith({
    bool showProgressIndicator,
    bool showBrightness,
    bool showVolume,
    Duration currentDuration,
    double currentBrightness,
    double currentVolume,
    DateTime lastProgressOperationAt,
    DateTime lastBrightnessOrVolumeOperationAt,
  }) =>
      _VideoIndicatorValue(
        showProgressIndicator: showProgressIndicator ?? this.showProgressIndicator,
        showBrightness: showBrightness ?? this.showBrightness,
        showVolume: showVolume ?? this.showVolume,
        currentDuration: currentDuration ?? this.currentDuration,
        currentBrightness: currentBrightness ?? this.currentBrightness,
        currentVolume: currentVolume ?? this.currentVolume,
        lastProgressOperationAt: lastProgressOperationAt ?? this.lastProgressOperationAt,
        lastBrightnessOrVolumeOperationAt:
            lastBrightnessOrVolumeOperationAt ?? this.lastBrightnessOrVolumeOperationAt,
      );
}

class _VideoIndicatorController extends ValueNotifier<_VideoIndicatorValue> {
  Timer _cleaner;

  _VideoIndicatorController(_VideoIndicatorValue value) : super(value);

  void initialize() {
    _cleaner = Timer.periodic(const Duration(seconds: 1), (timer) {
      final hasValue = (value.showBrightness || value.showVolume);
      final hasOperation = value.lastBrightnessOrVolumeOperationAt != null;
      if (hasValue && hasOperation) {
        final now = DateTime.now();
        if (now.difference(value.lastBrightnessOrVolumeOperationAt).inSeconds >= 3) {
          value = value.copyWith(
            showBrightness: false,
            showVolume: false,
            lastBrightnessOrVolumeOperationAt: now,
          );
        }
      }
    });
  }

  @override
  Future<void> dispose() async {
    _cleaner.cancel();
    super.dispose();
  }
}

class _VideoControlScrubber extends StatefulWidget {
  final Widget child;
  final AsunaVideoPlayerController controller;
  final bool isFullscreen;

  _VideoControlScrubber({this.child, @required this.controller, this.isFullscreen = false});

  @override
  State<StatefulWidget> createState() => _VideoControlScrubberState();
}

class _VideoControlScrubberState extends State<_VideoControlScrubber> {
  _VideoIndicatorController indicatorController;
  bool _controllerWasPlaying = false;
  Offset startPosition;
//  Duration currentDuration;
//  double currentVolume;
  double updateToVolume;
//  double currentBrightness;
  double updateToBrightness;
  bool isInBrightnessArea;
  bool isInVolumeArea;

  static const BrightnessIndicatorIndex = 0;
  static const VolumeIndicatorIndex = 1;

  AsunaVideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    Future.sync(() async {
      final brightness = await Screen.brightness;
      indicatorController = _VideoIndicatorController(_VideoIndicatorValue(
        currentBrightness: brightness,
        currentVolume: controller.value.volume,
        currentDuration: controller.value.position,
      ))
        ..initialize();
      updateToBrightness = brightness;
      updateToVolume = controller.value.volume;
    });
  }

  @override
  void dispose() {
    indicatorController.dispose();
    super.dispose();
  }

  void seekToRelativePosition(Offset globalPosition) {
    if (startPosition == null) {
      return;
    }

    final RenderBox box = context.findRenderObject();
    final Offset tapPos = box.globalToLocal(globalPosition);
    final double relative = (tapPos.dx - startPosition.dx) / (box.size.width / 2);
    final Duration position =
        indicatorController.value.currentDuration + controller.value.duration * relative;
    final Duration fixedPosition = position < const Duration()
        ? const Duration()
        : position > controller.value.duration ? controller.value.duration * .99 : position;

    _logger.info(
        'position: $tapPos relative: $relative duration: ${controller.value.duration} current: ${controller.value.position} position: $position fixedPosition: $fixedPosition'
        'calc (dx:${tapPos.dx} - start:${startPosition.dx}) / ${box.size.width / 2} fix: ${controller.value.duration * relative}');
    controller.seekTo(fixedPosition);
  }

  void updateBrightnessOrVolume(Offset globalPosition) async {
    if (startPosition == null) {
      return;
    }

    final RenderBox box = context.findRenderObject();
    final Offset tapPos = box.globalToLocal(globalPosition);
    final double relative = -(tapPos.dy - startPosition.dy) / (box.size.height * .8);

    _logger.finest('update $relative');

    if (isInVolumeArea == true) {
      var updateTo = indicatorController.value.currentVolume + relative;
      updateTo = updateTo > 1 ? 1 : updateTo < 0 ? 0 : updateTo;
      _logger.finest(
          'update volume ${indicatorController.value.currentVolume} -> updateTo: $updateTo');
      setState(() {
        updateToVolume = updateTo;
//        widget.indicatorShower.value = [true, false];
        indicatorController.value = indicatorController.value.copyWith(
          showBrightness: false,
          showVolume: true,
          lastBrightnessOrVolumeOperationAt: DateTime.now(),
        );
      });
      controller.setVolume(updateTo);
    } else if (isInBrightnessArea == true) {
      var updateTo = indicatorController.value.currentBrightness + relative;
      updateTo = updateTo > 1 ? 1 : updateTo < 0 ? .1 : updateTo;
      _logger.finest(
          'update brightness ${indicatorController.value.currentBrightness} -> updateTo: $updateTo');
      setState(() {
        updateToBrightness = updateTo;
//        widget.indicatorShower.value = [false, true];
        indicatorController.value = indicatorController.value.copyWith(
          showBrightness: true,
          showVolume: false,
          lastBrightnessOrVolumeOperationAt: DateTime.now(),
        );
      });
      Screen.setBrightness(updateTo);
    }
  }

  void updateStartPosition(Offset globalPosition) async {
    final RenderBox box = context.findRenderObject();
    final Offset tapPos = box.globalToLocal(globalPosition);
    startPosition = tapPos;

    final functionArea = box.size.width / 3;
    isInBrightnessArea = tapPos.dx < functionArea;
    isInVolumeArea = tapPos.dx > box.size.width - functionArea;

    indicatorController.value = indicatorController.value.copyWith(
      currentDuration: controller.value.position,
      currentBrightness: await Screen.brightness,
      currentVolume: controller.value.volume,
//      showBrightness: isInBrightnessArea,
//      showVolume: isInVolumeArea,
//      lastBrightnessOrVolumeOperationAt: DateTime.now(),
    );
//    currentDuration = controller.value.position;
//    currentVolume = controller.value.volume;
//    currentBrightness = await Screen.brightness;

    _logger.finest('update start position: $tapPos direction: ${tapPos.direction} '
        'isInBrightnessArea: $isInBrightnessArea, isInVolumeArea: $isInVolumeArea');
  }

  void endOperation() async {
    startPosition = null;
//    currentDuration = null;
//    currentVolume = null;
//    currentBrightness = null;
    isInBrightnessArea = false;
    isInVolumeArea = false;
    indicatorController.value = indicatorController.value.copyWith(
      currentDuration: controller.value.position,
      currentBrightness: await Screen.brightness,
      currentVolume: controller.value.volume,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (indicatorController == null) {
      return const SizedBox();
    }

    final fixedHeight = widget.isFullscreen ? MediaQuery.of(context).size.height / 2 - 80 : 30.0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      child: Stack(children: <Widget>[
//        widget.child,
        // brightness
        Positioned(
            left: 40,
            top: fixedHeight,
            child: Offstage(
                offstage: indicatorController.value.showBrightness == false,
                child: RotatedBox(
                    quarterTurns: -1,
                    child: Container(
                        width: 160,
                        child: LinearProgressIndicator(
                            valueColor: const AlwaysStoppedAnimation(Colors.pink),
                            backgroundColor: Colors.white30,
                            value: updateToBrightness))))),
        // volume
        Positioned(
            right: 40,
            top: fixedHeight,
            child: Offstage(
                offstage: indicatorController.value.showVolume == false,
                child: RotatedBox(
                    quarterTurns: -1,
                    child: Container(
                        width: 160,
                        child: LinearProgressIndicator(
                            valueColor: const AlwaysStoppedAnimation(Colors.pink),
                            backgroundColor: Colors.white30,
                            value: updateToVolume))))),
      ]),

      // --------------------------------------------------------------
      // adjust video position
      // --------------------------------------------------------------

      onHorizontalDragStart: (DragStartDetails details) {
        if (!controller.value.initialized) {
          return;
        }
        _logger.finest('onHorizontalDragStart $details');
        updateStartPosition(details.globalPosition);
        _controllerWasPlaying = controller.value.isPlaying;
        if (_controllerWasPlaying) {
          controller.pause();
        }
      },
      onHorizontalDragUpdate: (DragUpdateDetails details) {
        if (!controller.value.initialized) {
          return;
        }
        seekToRelativePosition(details.globalPosition);
      },
      onHorizontalDragEnd: (DragEndDetails details) {
        if (!controller.value.initialized) {
          return;
        }
        _logger.finest('onHorizontalDragEnd $details');
        endOperation();
        if (_controllerWasPlaying) {
          controller.play();
        }
      },

      // --------------------------------------------------------------
      // adjust volume or bright
      // --------------------------------------------------------------

      onVerticalDragStart: (DragStartDetails details) {
        if (!controller.value.initialized) {
          return;
        }
        _logger.finest('onVerticalDragStart $details');
        updateStartPosition(details.globalPosition);
      },
      onVerticalDragUpdate: (DragUpdateDetails details) {
        if (!controller.value.initialized) {
          return;
        }
        _logger.finest('onVerticalDragUpdate $details');
        updateBrightnessOrVolume(details.globalPosition);
      },
      onVerticalDragEnd: (DragEndDetails details) {
        if (!controller.value.initialized) {
          return;
        }
        _logger.finest('onVerticalDragEnd $details');
        endOperation();
      },
    );
  }
}

class FadeAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;

  FadeAnimation({this.child, this.duration = const Duration(milliseconds: 500)});

  @override
  State<StatefulWidget> createState() => _FadeAnimationState();
}

class _FadeAnimationState extends State<FadeAnimation> with SingleTickerProviderStateMixin {
  AnimationController animationController;

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(duration: widget.duration, vsync: this);
    animationController.addListener(() {
      if (mounted) {
        _logger.info('(animationController) update state ...');
        setState(() {});
      }
    });
    animationController.forward(from: 0);
  }

  @override
  void deactivate() {
    animationController.stop();
    super.deactivate();
  }

  @override
  void didUpdateWidget(FadeAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) {
      animationController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return animationController.isAnimating
        ? Opacity(opacity: 1.0 - animationController.value, child: widget.child)
        : Container();
  }
}

typedef Widget VideoWidgetBuilder(BuildContext context, AsunaVideoPlayerController controller);

abstract class PlayerLifeCycle extends StatefulWidget {
  final VideoWidgetBuilder childBuilder;
  final String dataSource;

  PlayerLifeCycle(this.dataSource, this.childBuilder);
}

class NetworkPlayerLifeCycle extends PlayerLifeCycle {
  NetworkPlayerLifeCycle(String dataSource, VideoWidgetBuilder childBuilder)
      : super(dataSource, childBuilder);

  @override
  State<StatefulWidget> createState() => _NetworkPlayerLifeCycleState();
}

class AssetPlayerLifeCycle extends PlayerLifeCycle {
  AssetPlayerLifeCycle(String dataSource, VideoWidgetBuilder childBuilder)
      : super(dataSource, childBuilder);

  @override
  _AssetPlayerLifeCycleState createState() => _AssetPlayerLifeCycleState();
}

abstract class _PlayerLifeCycleState extends State<PlayerLifeCycle> {
  AsunaVideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = createAsunaVideoPlayerController();
    controller.addListener(() {
      if (controller.value.hasError) {
        _logger.info(controller.value.errorDescription);
      }
    });
    controller.initialize();
//    controller.setLooping(true);
//    controller.play();
  }

  @override
  void deactivate() {
    _logger.info('_PlayerLifeCycleState(${controller.textureId}).deactive');
    controller.deactivate();
    super.deactivate();
  }

  @override
  void dispose() {
    _logger.info('_PlayerLifeCycleState(${controller.textureId}).dispose');
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _logger.info(
        '_PlayerLifeCycleState(${controller.textureId}).build widget is $widget childBuilder: ${widget.childBuilder != null}');
    return widget.childBuilder(context, controller);
  }

  AsunaVideoPlayerController createAsunaVideoPlayerController();
}

class _NetworkPlayerLifeCycleState extends _PlayerLifeCycleState {
  @override
  AsunaVideoPlayerController createAsunaVideoPlayerController() =>
      AsunaVideoPlayerController.network(widget.dataSource);
}

class _AssetPlayerLifeCycleState extends _PlayerLifeCycleState {
  @override
  AsunaVideoPlayerController createAsunaVideoPlayerController() =>
      AsunaVideoPlayerController.asset(widget.dataSource);
}

class AspectRatioVideo extends StatefulWidget {
  final AsunaVideoPlayerController controller;

  AspectRatioVideo(this.controller);

  @override
  State<StatefulWidget> createState() => AspectRatioVideoState();
}

class AspectRatioVideoState extends State<AspectRatioVideo> {
  bool initialized = false;
  VoidCallback listener;

  AsunaVideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    listener = () {
      if (!mounted) {
        return;
      }
      if (initialized != controller.value.initialized) {
        initialized = controller.value.initialized;
        _logger.info('(initState) update state ...');
        setState(() {});
      }
    };
    controller.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    _logger.info(
        'AspectRatioVideoState.build initialized(${controller.value.initialized}) ${MediaQuery.of(context).orientation}');

    return Container(
        color: Colors.black,
        child: Align(
            alignment: Alignment.center,
            child: controller.value.initialized
                ? VideoPlayPause(controller)
                : const CircularProgressIndicator()));
  }
}

class _FullscreenPlayer extends StatelessWidget {
  final AsunaVideoPlayerController controller;

  const _FullscreenPlayer({Key key, this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    _logger.info('_FullscreenPlayer.build');
    return Scaffold(
        body: Hero(
            tag: "fullscreenPlayer",
            child: Container(
                color: Colors.black,
                child: Align(
                    alignment: Alignment.center,
                    child: controller.value.initialized
                        ? VideoPlayPause(controller, isFullscreenMode: true)
                        : const CircularProgressIndicator()))));
  }
}
