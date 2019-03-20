import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import './asuna_video_player.dart';

typedef Widget VideoWidgetBuilder(BuildContext context, AsunaVideoPlayerController controller);

abstract class PlayerLifeCycle extends StatefulWidget {
  final VideoWidgetBuilder childBuilder;
  final String dataSource;

  PlayerLifeCycle(this.dataSource, this.childBuilder);
}

abstract class _PlayerLifeCycleState extends State<PlayerLifeCycle> {
  AsunaVideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    controller = instance();
    controller.addListener(() {
      if (controller.value.hasError) {
        print(controller.value.errorDescription);
      }
    });
    controller.initialize();
    controller.setLooping(true);
    controller.play();
  }

  @override
  void deactivate() {
    super.deactivate();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('widget is $widget');
    print(widget.childBuilder != null);

    return widget.childBuilder != null
        ? widget.childBuilder(context, controller)
        : AspectRatioVideo(controller);
  }

  AsunaVideoPlayerController instance();
}

class NetworkPlayerLifeCycle extends PlayerLifeCycle {
  NetworkPlayerLifeCycle(String dataSource, {VideoWidgetBuilder childBuilder})
      : super(dataSource, childBuilder);

  @override
  State<StatefulWidget> createState() => _NetworkPlayerLifeCycleState();
}

class _NetworkPlayerLifeCycleState extends _PlayerLifeCycleState {
  @override
  AsunaVideoPlayerController instance() => AsunaVideoPlayerController.network(widget.dataSource);
}

class VideoPlayPause extends StatefulWidget {
  final AsunaVideoPlayerController controller;

  VideoPlayPause(this.controller);

  @override
  State<StatefulWidget> createState() => _VideoPlayPauseState();
}

class _VideoPlayPauseState extends State<VideoPlayPause> {
  FadeAnimation imageFadeAnimation = FadeAnimation(child: Icon(Icons.play_arrow, size: 100.0));
  VoidCallback listener;

  _VideoPlayPauseState() {
    this.listener = () {
      setState(() {});
    };
  }

  AsunaVideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    print('_VideoPlayPauseState.initState ...');
    super.initState();
    controller.addListener(listener);
    controller.setVolume(1.0);
    controller.play();
  }

  @override
  void deactivate() {
    print('_VideoPlayPauseState.deactivate ...');
    controller.setVolume(0.0);
    controller.removeListener(listener);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    print('_VideoPlayPauseState.build ... ${controller.value}');

    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        GestureDetector(
          child: AsunaVideoPlayer(controller),
          onTap: () {
            if (!controller.value.initialized) {
              return;
            }
            if (controller.value.isPlaying) {
              imageFadeAnimation = FadeAnimation(child: const Icon(Icons.pause, size: 100.0));
              controller.pause();
            } else {
              imageFadeAnimation = FadeAnimation(child: const Icon(Icons.play_arrow, size: 100.0));
              controller.play();
            }
          },
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: VideoProgressIndicator(controller, allowScrubbing: true),
        ),
        Center(child: imageFadeAnimation),
        Center(
            child: controller.value.isBuffering
                ? const Icon(Icons.check_circle, size: 100.0) // circular progress indicator
                : null)
      ],
    );
  }
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
    print('AspectRatioVideoState initState...');
    listener = () {
      print(
          'AspectRatioVideoState initState... mounted: $mounted, initialized: ${controller.value.initialized}');
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
    print('AspectRatioVideoState build... $initialized');
    if (initialized) {
      final Size size = controller.value.size;
      return Center(
        child: AspectRatio(
          aspectRatio: size.width / size.height,
          child: VideoPlayPause(controller),
        ),
      );
    } else {
      return Container();
    }
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
  Widget build(BuildContext context) => animationController.isAnimating
      ? Opacity(opacity: 1.0 - animationController.value, child: widget.child)
      : Container();
}
