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

  _VideoPlayPauseState() {
    listener = () {
      setState(() {});
    };
  }

  AsunaVideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    _logger.info('_VideoPlayPauseState.initState ...');
    super.initState();
    controller.addListener(listener);
    isLayoutVisible = !controller.value.isPlaying;
//    controller.setVolume(1.0);
//    controller.play();
  }

  @override
  void deactivate() {
    _logger.info('_VideoPlayPauseState.deactivate ... pause');
    controller.pause();
//    controller.setVolume(0.0);
    controller.removeListener(listener);
    super.deactivate();
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
        swipeDetectionBehavior: SwipeDetectionBehavior.continuousDistinct,
      ),
      child: GestureDetector(
        child: AsunaVideoPlayer(controller),
        onTap: () {
          if (controller.value.isPlaying) {
            setState(() => isLayoutVisible = true);
            Timer.periodic(new Duration(seconds: 3), (timer) {
              if (controller.value.isPlaying) {
                setState(() => isLayoutVisible = false);
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

  final TextStyle _textStyle = const TextStyle(color: Colors.white, fontSize: 16);

  void play() {
    controller.play();
    if (isLayoutVisible) {
      Timer.periodic(new Duration(seconds: 1), (timer) {
        setState(() => isLayoutVisible = false);
        timer.cancel();
      });
    }
  }

  void pause() {
    controller.pause();
  }

  List<Widget> _buildPortraitLayout() {
    final position = controller.value.position;
    final duration = controller.value.duration;
    return [
      Align(
        alignment: Alignment.topRight,
        child: SizedBox(
          height: 24,
          child: Row(),
        ),
      ),
      Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 6),
          child: SizedBox(
            height: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
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
                Expanded(child: VideoProgressIndicator(controller, allowScrubbing: true)),
                SizedBox(
                  width: 85,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                        '${position.inMinutes}:${position.inSeconds % 60}/${duration.inMinutes}:${duration.inSeconds % 60}',
                        style: _textStyle),
                  ),
                ),
                SizedBox(
                    width: 30,
                    child: SizedBox.expand(
                      child: WillPopScope(
                          onWillPop: () {
                            // back to portrait when tap back
                            if (MediaQuery.of(context).orientation == Orientation.landscape) {
                              SystemChrome.setPreferredOrientations(
                                  [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
                              SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
                            }
                            return Future.value(true);
                          },
                          child: MaterialButton(
                            padding: EdgeInsets.all(0),
                            onPressed: () {
                              if (MediaQuery.of(context).orientation == Orientation.portrait) {
                                SystemChrome.setPreferredOrientations([
                                  DeviceOrientation.landscapeLeft,
                                  DeviceOrientation.landscapeRight
                                ]);
                                SystemChrome.setEnabledSystemUIOverlays([]);
                              } else {
                                SystemChrome.setPreferredOrientations(
                                    [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
                                SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
                              }
                            },
                            child: const Icon(Icons.fullscreen, color: Colors.white),
                          )),
                    )),
              ],
            ),
          ),
        ),
      ),
      Center(
        child: AnimatedOpacity(
          opacity: controller.value.isPlaying ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: const Icon(Icons.pause, size: 100.0, color: Colors.white54),
        ),
      ),
    ];
  }

  List<Widget> _buildLandscapeLayout() {
    return [
      Align(
        alignment: Alignment.bottomCenter,
        child: Row(
          children: <Widget>[
            SizedBox(
                width: 40,
                child: controller.value.isPlaying
                    ? const Icon(Icons.play_arrow, color: Colors.white70)
                    : const Icon(Icons.pause, color: Colors.white70)),
            Expanded(child: VideoProgressIndicator(controller, allowScrubbing: true)),
            SizedBox(
                width: 40,
                child: FlatButton(
                    onPressed: () {
                      if (MediaQuery.of(context).orientation == Orientation.portrait) {
                        SystemChrome.setPreferredOrientations(
                            [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
                      } else {
                        SystemChrome.setPreferredOrientations(
                            [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
                      }
                    },
                    child: const Icon(Icons.fullscreen, color: Colors.white70))),
          ],
        ),
      ),
      Center(
        child: AnimatedOpacity(
          opacity: controller.value.isPlaying ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: const Icon(Icons.pause, size: 100.0, color: Colors.white54),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        _buildGesture(),
        Center(child: controller.value.isBuffering ? const CircularProgressIndicator() : null),
      ]..addAll(isLayoutVisible
          ? _buildPortraitLayout() ??
              (MediaQuery.of(context).orientation == Orientation.portrait
                  ? _buildPortraitLayout()
                  : _buildLandscapeLayout())
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
  final Function(String text) onSendText;

  AspectRatioVideo(this.controller, {this.onSendText});

  @override
  State<StatefulWidget> createState() => AspectRatioVideoState();
}

class AspectRatioVideoState extends State<AspectRatioVideo> {
  bool initialized = false;
  VoidCallback listener;
  TextEditingController textEditingController;

  AsunaVideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    textEditingController = TextEditingController();
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
    _logger.info('AspectRatioVideoState.build $initialized ${MediaQuery.of(context).orientation}');
    final Size size = controller.value.size;
    if (initialized && MediaQuery.of(context).orientation == Orientation.landscape)
      return Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        color: Colors.black,
        child: Center(
          child: initialized
              ? AspectRatio(
                  aspectRatio: size.width / size.height,
                  child: VideoPlayPause(controller),
                )
              : const CircularProgressIndicator(),
        ),
      );

    return Column(
      children: <Widget>[
        Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.width * MediaQuery.of(context).size.aspectRatio,
          color: Colors.black,
          child: Center(
            child: initialized
                ? AspectRatio(
                    aspectRatio: size.width / size.height,
                    child: VideoPlayPause(controller),
                  )
                : const CircularProgressIndicator(),
          ),
        ),
        widget.onSendText != null
            ? Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                    controller: textEditingController,
                    maxLength: 20,
                    onSubmitted: (text) {
                      widget.onSendText(text);
                      textEditingController.clear();
                    }))
            : const SizedBox(),
      ],
    );
  }
}
