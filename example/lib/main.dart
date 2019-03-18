import 'dart:async';

import 'package:asuna_video_player/asuna_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  String _status = "ready";
  Duration _duration = Duration(seconds: 0);
  Duration _position = Duration(seconds: 0);

  AsunaVideoPlayerController controller;

  @override
  void initState() {
    super.initState();
    initPlatformState();

//    AsunaVideoPlayer.listenStatus(_onPlayerStatus, _onPlayerStatusError);
//    AsunaVideoPlayer.listenPosition(_onPosition, _onPlayerStatusError);
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await AsunaVideoPlayer.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    print("Platform version is $platformVersion");

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  void _playPause() {
//    switch (_status) {
//      case "started":
//        AsunaVideoPlayer.pause();
//        break;
//      case "paused":
//      case "completed":
//        AsunaVideoPlayer.start();
//        break;
//    }
  }

  void _open() {
//    AsunaVideoPlayer.open();
  }

  void _onPlayerStatus(Object event) {
    setState(() {
      _status = event;
    });
    if (_status == 'started') {
      _getDuration();
    }
  }

  void _onPlayerStatusError(Object event) {
    print(event);
  }

  void _getDuration() async {
    Duration duration = await AsunaVideoPlayer.duration;
    setState(() {
      _duration = duration;
    });
  }

  void _onPosition(Object event) {
    Duration position = Duration(milliseconds: event);
    setState(() {
      _position = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin asuna video player app'),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Running on: $_platformVersion\n'),
            Center(child: Text(_status.toUpperCase(), style: TextStyle(fontSize: 32))),
//            Expanded(child: Visualizer()),
//            Expanded(child: AsunaVideoPlayer(controller)),
//            Expanded(child: AspectRatioVideo(controller)),
            Expanded(
                child: NetworkPlayerLifeCycle(
                    'https://www.sample-videos.com/video123/mp4/720/big_buck_bunny_720p_20mb.mp4',
                    (context, controller) => AspectRatioVideo(controller))),
            Center(
              child: Text(
                _position.toString().split('.').first + "/" + _duration.toString().split('.').first,
                style: TextStyle(fontSize: 24),
              ),
            ),
            IconButton(
              icon: Icon(_status == "started" ? Icons.pause : Icons.play_arrow),
              onPressed: _status == "started" || _status == "paused" || _status == "completed"
                  ? _playPause
                  : null,
              iconSize: 64,
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayPause extends StatefulWidget {
  final AsunaVideoPlayerController controller;

  VideoPlayPause(this.controller);

  @override
  State<StatefulWidget> createState() => _VideoPlayPauseState();
}

class _VideoPlayPauseState extends State<VideoPlayPause> {
  Widget imageFadeAnimation = Container(child: Icon(Icons.play_arrow, size: 100.0));
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
//    controller.setVolume(1.0);
    controller.play();
  }

  @override
  void deactivate() {
    print('_VideoPlayPauseState.deactivate ...');
    //    controller.setVolume(0.0);
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
              imageFadeAnimation = const Icon(Icons.pause, size: 100.0);
              controller.pause();
            } else {
              imageFadeAnimation = const Icon(Icons.play_arrow, size: 100.0);
              controller.play();
            }
          },
        ),
//      Align(
//        alignment: Alignment.bottomCenter,
//    progress indicator
//      ),
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
  Widget build(BuildContext context) => widget.childBuilder(context, controller);

  AsunaVideoPlayerController instance();
}

class NetworkPlayerLifeCycle extends PlayerLifeCycle {
  NetworkPlayerLifeCycle(String dataSource, VideoWidgetBuilder childBuilder)
      : super(dataSource, childBuilder);

  @override
  State<StatefulWidget> createState() => _NetworkPlayerLifeCycleState();
}

class _NetworkPlayerLifeCycleState extends _PlayerLifeCycleState {
  @override
  AsunaVideoPlayerController instance() => AsunaVideoPlayerController.network(widget.dataSource);
}
