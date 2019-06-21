import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:logging/logging.dart';
import 'package:simple_gesture_detector/simple_gesture_detector.dart';

import './asuna_video_player.dart';

final _logger = Logger('AsunaVideoPlayerWidget');

class VideoPlayPause extends StatefulWidget {
  final AsunaVideoPlayerController controller;

  VideoPlayPause(this.controller);

  @override
  State<StatefulWidget> createState() => _VideoPlayPauseState();
}

class _VideoPlayPauseState extends State<VideoPlayPause> {
  VoidCallback listener;
  bool isLayoutVisible;
  bool inactive;
  double videoRatio;
  bool isPortrait;

  _VideoPlayPauseState() {
    listener = () {
      if (isLayoutVisible && !inactive) setState(() {});
    };
  }

  AsunaVideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    _logger.info('_VideoPlayPauseState.initState ...');
    inactive = false;
    super.initState();
    controller.addListener(listener);
    isLayoutVisible = !controller.value.isPlaying;

//    final Size size = controller.value.size;
//    videoRatio = size != null ? size.width / size.height : 1;
//    controller.setVolume(1.0);
//    controller.play();
  }

  @override
  void deactivate() {
    _logger.info('_VideoPlayPauseState.deactivate ... pause');
    inactive = true;
    controller.pause();
//    controller.setVolume(0.0);
    controller.removeListener(listener);
    super.deactivate();
  }

  final TextStyle _textStyle = const TextStyle(color: Colors.white, fontSize: 12);

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

  Widget _buildGesture() {
    return SimpleGestureDetector(
      onVerticalSwipe: (SwipeDirection direction) {
        _logger.info('onVerticalSwipe: $direction');
      },
      onHorizontalSwipe: (SwipeDirection direction) {
        _logger.info('onHorizontalSwipe: $direction');
      },
      swipeConfig: SimpleSwipeConfig(
          verticalThreshold: 40.0,
          horizontalThreshold: 40.0,
          swipeDetectionBehavior: SwipeDetectionBehavior.continuousDistinct),
      child: GestureDetector(
        child: Container(
            constraints: BoxConstraints.expand(),
            child: Align(
                alignment: Alignment.center,
                child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: AsunaVideoPlayer(controller)))),
        onDoubleTap: () {
          _logger.info('onDoubleTap ...');
          if (!isPortrait) {
            controller.value.isPlaying ? controller.pause() : controller.play();
          }
        },
        onTap: () {
          _logger.info('onTap ...');
          if (controller.value.isPlaying) {
            setState(() => isLayoutVisible = true);
            Timer.periodic(new Duration(seconds: 3), (timer) {
              _logger.info('check status ... playing: ${controller.value.isPlaying}');
              if (controller.value.isPlaying) {
                if (mounted) setState(() => isLayoutVisible = false);
              }
              timer.cancel();
            });
          } else {
            setState(() => isLayoutVisible = true);
          }
        },
      ),
    );
  }

  Widget _buildPlayPauseIndicator() {
//    _logger.info('_buildPlayPauseIndicator: playing status: ${controller.value.isPlaying}');
    return Center(
        child: InkWell(
            onTap: () => setState(() => controller.value.isPlaying ? pause() : play()),
            child: AnimatedOpacity(
                opacity: controller.value.isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: const Icon(Icons.pause, size: 100.0, color: Colors.white54))));
  }

  List<Widget> _buildPortraitLayout() {
    final position = controller.value.position;
    final duration = controller.value.duration;
    return [
      Align(alignment: Alignment.topRight, child: SizedBox(height: 24, child: Row())),
      Align(
          alignment: Alignment.bottomCenter,
          child: Container(
              margin: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                  height: 24,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                    // play/pause button
                    SizedBox(
                        width: 40,
                        child: MaterialButton(
                            onPressed: () {
                              controller.value.isPlaying ? pause() : play();
                            },
                            padding: EdgeInsets.all(0),
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
                        width: 30,
                        child: SizedBox.expand(
                            child: WillPopScope(
                                onWillPop: () {
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
                                  padding: EdgeInsets.all(0),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) {
                                      SystemChrome.setPreferredOrientations([
                                        DeviceOrientation.landscapeLeft,
                                        DeviceOrientation.landscapeRight
                                      ]);
                                      SystemChrome.setEnabledSystemUIOverlays([]);
                                      return _FullscreenPlayer(controller: controller);
                                    }));
                                  },
                                  child: const Icon(Icons.fullscreen, color: Colors.white),
                                )))),
                  ])))),
      _buildPlayPauseIndicator(),
    ];
  }

  List<Widget> _buildLandscapeLayout() {
    return [
      Align(
          alignment: Alignment.bottomCenter,
          child: Row(children: <Widget>[
            // play/pause button
            SizedBox(
                width: 40,
                child: controller.value.isPlaying
                    ? const Icon(Icons.play_arrow, color: Colors.white70)
                    : const Icon(Icons.pause, color: Colors.white70)),
            // progress indicator
            Expanded(child: VideoProgressIndicator(controller, allowScrubbing: true)),
            // fullscreen button
            SizedBox(
                width: 40,
                child: FlatButton(
                    onPressed: () {
                      SystemChrome.setPreferredOrientations(
                          [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.fullscreen, color: Colors.white70))),
          ])),
      _buildPlayPauseIndicator(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        _buildGesture(),
      ]
        ..add(controller.value.isBuffering
            ? const Center(child: const CircularProgressIndicator())
            : const SizedBox())
        ..addAll(isLayoutVisible
            ? (isPortrait ? _buildPortraitLayout() : _buildLandscapeLayout())
            : [const SizedBox()]),
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
    _logger.info('_PlayerLifeCycleState.deactive');
    controller.deactivate();
    super.deactivate();
  }

  @override
  void dispose() {
    _logger.info('_PlayerLifeCycleState.dispose');
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _logger.info('build widget is $widget childBuilder: ${widget.childBuilder != null}');
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
  final bool autoPlay;

  AspectRatioVideo(this.controller, {this.autoPlay = true});

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
        setState(() {});
      }
    };
    controller.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    _logger.info(
        'AspectRatioVideoState.build initialized($initialized) ${MediaQuery.of(context).orientation}');

    return Container(
        color: Colors.black,
        child: Align(
            alignment: Alignment.center,
            child: initialized ? VideoPlayPause(controller) : const CircularProgressIndicator()));
  }
}

class _FullscreenPlayer extends StatelessWidget {
  final AsunaVideoPlayerController controller;

  const _FullscreenPlayer({Key key, this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    _logger.info('_FullscreenPlayer build');
    return Scaffold(
        body: Hero(
            tag: "fullscreenPlayer",
            child: Container(
                color: Colors.black,
                child: Align(
                    alignment: Alignment.center,
                    child: controller.value.initialized
                        ? VideoPlayPause(controller)
                        : const CircularProgressIndicator()))));
  }
}
