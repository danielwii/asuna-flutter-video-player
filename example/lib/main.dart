import 'dart:math';

import 'package:asuna_video_player/asuna_video_player.dart';
import 'package:flutter_barrage/flutter_barrage.dart';
import 'package:flutter/material.dart';
import 'package:screen/screen.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AsunaVideoPlayerController playerController;
  ValueNotifier<BarrageValue> timelineNotifier;
  Random random = new Random();

  @override
  void initState() {
    super.initState();
    timelineNotifier = ValueNotifier(BarrageValue());
  }

  @override
  void dispose() {
    super.dispose();
    playerController?.dispose();
    timelineNotifier?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print('main.build ...');
//    return VideoApp();

    return MaterialApp(
      home: Scaffold(
        /*
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              playerController.value.isPlaying ?? false
                  ? playerController.pause()
                  : playerController.play();
            });
          },
          child: Icon(
            playerController?.value?.isPlaying ?? false ? Icons.pause : Icons.play_arrow,
          ),
        ),*/
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              NetworkPlayerLifeCycle(
//        'https://www.sample-videos.com/video123/mp4/240/big_buck_bunny_240p_30mb.mp4',
                "http://10.0.2.2:8000/big_buck_bunny_720p_20mb.mp4",
//                "http://192.168.0.100:8000/big_buck_bunny_720p_20mb.mp4",
                (BuildContext context, AsunaVideoPlayerController controller) {
                  playerController = controller;
                  controller.initializingCompleter.future.then((_) {
//                  controller.play();
                  });
                  return AspectRatioVideo(controller);
                  return Positioned(
                    width: MediaQuery.of(context).size.width,
                    height:
                        MediaQuery.of(context).size.width * MediaQuery.of(context).size.aspectRatio,
                    child: Container(
                        margin: EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.8)),
                        child: AspectRatioVideo(controller)),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
/*
    List<Bullet> bullets = const <Bullet>[
      const Bullet(child: Text('2423423'), showTime: 1200),
    ];*/

    List<Bullet> bullets = <Bullet>[
      const Bullet(child: Text('2423423'), showTime: 1200),
      const Bullet(child: Text('1123123'), showTime: 4200),
      const Bullet(child: Text('35345345'), showTime: 10200),
      const Bullet(child: Text('4gsgse'), showTime: 9200),
      const Bullet(child: Text('5nghnfh'), showTime: 5200),
      const Bullet(child: Text('6^_^'), showTime: 7200),
//      const Bullet(child: Text('16^_^'), showTime: 60720),
//      const Bullet(child: Text('26^_^'), showTime: 70720),
//      const Bullet(child: Text('36^_^'), showTime: 65720),
    ]..addAll(List<Bullet>.generate(1000, (i) {
        final showTime = random.nextInt(60000);
        return Bullet(child: Text('$i-$showTime}'), showTime: showTime);
      }).toList(growable: false));

    return MaterialApp(
      home: LayoutBuilder(builder: (context, snapshot) {
        print('main.LayoutBuilder ... ${MediaQuery.of(context).size.width}');
        return Scaffold(
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              setState(() {
                playerController.value.isPlaying ?? false
                    ? playerController.pause()
                    : playerController.play();
              });
            },
            child: Icon(
              playerController?.value?.isPlaying ?? false ? Icons.pause : Icons.play_arrow,
            ),
          ),
          body: SafeArea(
            child: Stack(
              children: <Widget>[
                Positioned(
                  width: MediaQuery.of(context).size.width,
                  height:
                      MediaQuery.of(context).size.width * MediaQuery.of(context).size.aspectRatio,
                  child: BarrageWall(
                    debug: true,
                    timelineNotifier: timelineNotifier,
                    bullets: [] ?? bullets,
                    child: NetworkPlayerLifeCycle(
                      "http://10.0.2.2:8000/big_buck_bunny_720p_20mb.mp4",
//                      "http://192.168.0.100:8000/big_buck_bunny_720p_20mb.mp4",
                      (BuildContext context, AsunaVideoPlayerController controller) {
                        playerController = controller;
                        controller.addListener(() {
                          print('update ${controller.value}');
                          timelineNotifier.value = timelineNotifier.value.copyWith(
                            timeline: controller.value.position.inMilliseconds,
                            isPlaying: controller.value.isPlaying,
                          );
                        });
                        print('NetworkPlayerLifeCycle.build ...');
                        return AspectRatioVideo(controller);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class VideoApp extends StatefulWidget {
  @override
  _VideoAppState createState() => _VideoAppState();
}

class _VideoAppState extends State<VideoApp> {
  AsunaVideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AsunaVideoPlayerController.network(
//      'http://www.sample-videos.com/video123/mp4/720/big_buck_bunny_720p_20mb.mp4',
      'http://10.0.2.2:8000/big_buck_bunny_720p_20mb.mp4',
//      'http://192.168.0.100:8000/big_buck_bunny_720p_20mb.mp4',
    )..initialize().then((_) {
        // Ensure the first frame is shown after the video is initialized, even before the play button has been pressed.
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Demo',
      home: Scaffold(
        body: Center(
          child: _controller.value.initialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: AsunaVideoPlayer(_controller),
                )
              : Container(),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            setState(() {
              _controller.value.isPlaying ? _controller.pause() : _controller.play();
            });
          },
          child: Icon(
            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}
