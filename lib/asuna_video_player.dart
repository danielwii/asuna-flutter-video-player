import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:screen/screen.dart';
import 'package:logging/logging.dart';

export 'widgets.dart';

final _logger = Logger('AsunaVideoPlayer');

typedef void EventHandler(Object event);

final MethodChannel _channel = const MethodChannel('asuna_video_player')
// This will clear all open videos on the platform when a full restart is performed.
  ..invokeMethod<void>("init");

class DurationRange {
  final Duration start;
  final Duration end;

  DurationRange(this.start, this.end);

  double startFraction(Duration duration) {
    return start.inMilliseconds / duration.inMilliseconds;
  }

  double endFraction(Duration duration) {
    return end.inMilliseconds / duration.inMilliseconds;
  }

  @override
  String toString() => '$runtimeType{start: $start, end: $end}';
}

class _AsunaVideoPlayerValue {
  /// The total duration of the video.
  ///
  /// Is null when [initialized] is false;
  final Duration duration;

  /// The current playback position.
  final Duration position;

  /// The currently buffered ranges.
  final List<DurationRange> buffered;

  /// True if the video is playing. False if it's paused.
  final bool isPlaying;

  /// True if the video is looping.
  final bool isLooping;

  /// True if the video is currently buffering.
  final bool isBuffering;

  /// The current volume of the playback.
  final double volume;

  /// A description of the error if preset.
  ///
  /// If [hasError] is false this is [null];
  final String errorDescription;

  /// The [size] of the currently loaded video.
  ///
  /// Is null when [initialized] is false.
  final Size size;

  bool get initialized => duration != null;
  bool get hasError => errorDescription != null;
  double get aspectRatio => size != null ? size.width / size.height : 1.0;

  _AsunaVideoPlayerValue({
    @required this.duration,
    this.size,
    this.position = const Duration(),
    this.buffered = const <DurationRange>[],
    this.isPlaying = false,
    this.isLooping = false,
    this.isBuffering = false,
    this.volume = 1.0,
    this.errorDescription,
  });

  _AsunaVideoPlayerValue.uninitialized() : this(duration: null);

  _AsunaVideoPlayerValue.erroneous(String errorDescription)
      : this(duration: null, errorDescription: errorDescription);

  _AsunaVideoPlayerValue copyWith({
    Duration duration,
    Size size,
    Duration position,
    List<DurationRange> buffered,
    bool isPlaying,
    bool isLooping,
    bool isBuffering,
    double volume,
    String errorDescription,
  }) {
    return _AsunaVideoPlayerValue(
      duration: duration ?? this.duration,
      size: size ?? this.size,
      position: position ?? this.position,
      buffered: buffered ?? this.buffered,
      isPlaying: isPlaying ?? this.isPlaying,
      isLooping: isLooping ?? this.isLooping,
      isBuffering: isBuffering ?? this.isBuffering,
      volume: volume ?? this.volume,
      errorDescription: errorDescription ?? this.errorDescription,
    );
  }

  @override
  String toString() {
    return '$runtimeType{duration: $duration, '
        'position: $position, '
        'buffered: $buffered, '
        'isPlaying: $isPlaying, '
        'isLooping: $isLooping, '
        'isBuffering: $isBuffering, '
        'volume: $volume, '
        'errorDescription: $errorDescription, '
        'size: $size}';
  }
}

enum DataSourceType { asset, network, file }

class AsunaVideoPlayerController extends ValueNotifier<_AsunaVideoPlayerValue> {
  final String dataSource;
  final DataSourceType dataSourceType;
  final String package;
  final Completer<void> initializingCompleter;

  int _textureId;
  Timer _timer;
  bool _isDisposed = false;

  /// used to avoid exceptions in listener when widget being deactivated
  bool _isDeactivated = false;
  Completer<void> _creatingCompleter;
  StreamSubscription<dynamic> _eventSubscription;
  _VideoAppLifeCycleObserver _lifeCycleObserver;

  AsunaVideoPlayerController.asset(this.dataSource, {this.package})
      : dataSourceType = DataSourceType.asset,
        initializingCompleter = Completer<void>(),
        super(_AsunaVideoPlayerValue(duration: null));

  AsunaVideoPlayerController.network(this.dataSource)
      : dataSourceType = DataSourceType.network,
        package = null,
        initializingCompleter = Completer<void>(),
        super(_AsunaVideoPlayerValue(duration: null));

  AsunaVideoPlayerController.file(File file)
      : dataSource = 'file://${file.path}',
        dataSourceType = DataSourceType.file,
        package = null,
        initializingCompleter = Completer<void>(),
        super(_AsunaVideoPlayerValue(duration: null));

  int get textureId => _textureId;
  bool get isDisposed => _isDisposed;

  Future<void> initialize() async {
    _logger.info('AsunaVideoPlayerController.initialize $dataSource');
    _lifeCycleObserver = _VideoAppLifeCycleObserver(this);
    _lifeCycleObserver.initialize();
    _creatingCompleter = Completer<void>();

    Map<dynamic, dynamic> dataSourceDescription;
    switch (dataSourceType) {
      case DataSourceType.asset:
        dataSourceDescription = <String, dynamic>{'asset': dataSource, 'package': package};
        break;
      case DataSourceType.network:
        dataSourceDescription = <String, dynamic>{'uri': dataSource};
        break;
      case DataSourceType.file:
        dataSourceDescription = <String, dynamic>{'uri': dataSource};
    }

    final Map<String, dynamic> response =
        await _channel.invokeMapMethod<String, dynamic>("create", dataSourceDescription);

    _logger.info('dataSourceDescription: $dataSourceDescription');
    _logger.info('response: $response');
    _textureId = response['textureId'];
    _creatingCompleter.complete();
//    final Completer<void> initializingCompleter = Completer<void>();

    DurationRange toDurationRange(dynamic value) {
      final List<dynamic> pair = value;
      return DurationRange(Duration(milliseconds: pair[0]), Duration(milliseconds: pair[1]));
    }

    void eventListener(dynamic event) {
      final Map<dynamic, dynamic> map = event;
      switch (map['event']) {
        case 'initialized':
          value = value.copyWith(
            duration: Duration(milliseconds: map['duration']),
            size: Size(map['width']?.toDouble() ?? 0.0, map['height']?.toDouble() ?? 0.0),
          );
          initializingCompleter.complete(null);
          _applyLooping();
          _applyVolume();
          _applyPlayPause();
          break;
        case 'completed':
          value = value.copyWith(isPlaying: false);
          _timer?.cancel();
          break;
        case 'bufferingUpdate':
          final List<dynamic> values = map['values'];
          value = value.copyWith(buffered: values.map<DurationRange>(toDurationRange).toList());
          break;
        case 'bufferingStart':
          value = value.copyWith(isBuffering: true);
          break;
        case 'bufferingEnd':
          value = value.copyWith(isBuffering: false);
          break;
      }
    }

    void errorListener(Object error) {
      final PlatformException e = error;
      value = _AsunaVideoPlayerValue.erroneous(e.message);
      _timer?.cancel();
    }

    _eventSubscription = _eventChannelFor(_textureId)
        .receiveBroadcastStream()
        .listen(eventListener, onError: errorListener);

    return initializingCompleter.future;
  }

  EventChannel _eventChannelFor(int textureId) =>
      EventChannel('asuna_video_player/videoEvents$textureId');

  deactivate() {
    _isDeactivated = true;
  }

  @override
  Future<void> dispose() async {
    if (_creatingCompleter != null) {
      await _creatingCompleter.future;
      if (!_isDisposed) {
        _isDisposed = true;
        _timer?.cancel();
        await _eventSubscription?.cancel();
        _logger.info('AsunaVideoPlayerController($textureId).dispose');
        await _channel.invokeMethod<void>(
          'dispose',
          <String, dynamic>{'textureId': _textureId},
        );
      }
      _lifeCycleObserver.dispose();
    }
    super.dispose();
  }

  Future<void> play() async {
    _logger.info('AsunaVideoPlayerController play isDisposed: $_isDisposed');
    Screen.keepOn(true);
    value = value.copyWith(isPlaying: true);
    await _applyPlayPause();
  }

  Future<void> setLooping(bool looping) async {
    value = value.copyWith(isLooping: looping);
  }

  Future<void> pause() async {
    _logger.info('AsunaVideoPlayerController pause isDisposed: $_isDisposed');
    if (_isDisposed) {
      return;
    }
    Screen.keepOn(false);
    value = value.copyWith(isPlaying: false);
    await _applyPlayPause();
  }

  Future<void> _applyLooping() async {
    if (!value.initialized || _isDisposed) {
      return;
    }
    _channel.invokeMethod<void>(
        'setLooping', <String, dynamic>{'textureId': _textureId, 'looping': value.isLooping});
  }

  Future<void> _applyPlayPause() async {
    _logger
        .info('AsunaVideoPlayerController._applyPlayPause value: $value, isDisposed: $_isDisposed');
    if (!value.initialized || _isDisposed) {
      return;
    }
    if (value.isPlaying) {
      await _channel.invokeMethod<void>('play', <String, dynamic>{'textureId': _textureId});
      _timer = Timer.periodic(const Duration(milliseconds: 500), (Timer timer) async {
        if (!value.isPlaying) {
          timer?.cancel();
        }
        if (_isDisposed) {
          return;
        }
        final Duration newPosition = await position;
        if (_isDisposed) {
          return;
        }
        value = value.copyWith(position: newPosition);
      });
    } else {
      _timer?.cancel();
      _logger.info('call pause isDisposed: $_isDisposed $value');
      await _channel.invokeMethod<void>('pause', <String, dynamic>{'textureId': _textureId});
    }
  }

  Future<void> _applyVolume() async {
    if (!value.initialized || _isDisposed) {
      return;
    }
    await _channel.invokeMethod<void>(
        'setVolume', <String, dynamic>{'textureId': _textureId, 'volume': value.volume});
  }

  Future<Duration> get position async {
    if (_isDisposed) {
      return null;
    }
    final milliseconds = await _channel.invokeMethod<int>(
      'position',
      <String, dynamic>{'textureId': textureId},
    ).catchError((e) {
      _logger.warning('call postion error: $e');
      return null;
    });
    return Duration(
      milliseconds: milliseconds,
    );
  }

  Future<void> seekTo(Duration moment) async {
    if (_isDisposed) {
      return;
    }
    if (moment > value.duration) {
      moment = value.duration;
    } else if (moment < const Duration()) {
      moment = const Duration();
    }
    await _channel.invokeMethod<void>('seekTo', <String, dynamic>{
      'textureId': _textureId,
      'location': moment.inMilliseconds,
    });
    value = value.copyWith(position: moment);
  }

  /// Sets the audio volume of [this].
  ///
  /// [volume] indicates a value between 0.0 (silent) and 1.0 (full volume) on a
  /// linear scale.
  Future<void> setVolume(double volume) async {
//    _logger.info('AsunaVideoPlayerController setVolume($volume)');
    value = value.copyWith(volume: volume.clamp(0.0, 1.0));
    await _applyVolume();
  }
}

class _VideoAppLifeCycleObserver extends Object with WidgetsBindingObserver {
  bool _wasPlayingBeforePause = false;
  final AsunaVideoPlayerController _controller;

  _VideoAppLifeCycleObserver(this._controller);

  void initialize() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _wasPlayingBeforePause = _controller.value.isPlaying;
        _controller.pause();
        break;
      case AppLifecycleState.resumed:
        if (_wasPlayingBeforePause) {
          _controller.play();
        }
        break;
      default:
    }
  }

  void dispose() {
    _logger.info('AsunaVideoPlayerController dispose ...');
    WidgetsBinding.instance.removeObserver(this);
  }
}

class AsunaVideoPlayer extends StatefulWidget {
  final AsunaVideoPlayerController controller;

  const AsunaVideoPlayer(this.controller);

  @override
  State<StatefulWidget> createState() => _AsunaVideoPlayerState();
}

class _AsunaVideoPlayerState extends State<AsunaVideoPlayer> {
  VoidCallback _listener;
  int _textureId;

  _AsunaVideoPlayerState() {
    _listener = () {
      final int newTextureId = widget.controller.textureId;
      if (newTextureId != _textureId) {
        setState(() {
          _textureId = newTextureId;
        });
      }
    };
  }

  @override
  void initState() {
    super.initState();
    _textureId = widget.controller.textureId;
    // Need to listen for initialization events since the actual texture ID
    // becomes available after asynchronous initialization finishes.
    widget.controller.addListener(_listener);
  }

  @override
  void didUpdateWidget(AsunaVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller.removeListener(_listener);
    _textureId = widget.controller.textureId;
    widget.controller.addListener(_listener);
  }

  @override
  void deactivate() {
    super.deactivate();
    if (!widget.controller.isDisposed) widget.controller.removeListener(_listener);
  }

  /// video texture
  @override
  Widget build(BuildContext context) {
    return _textureId == null
        ? Container(child: Text("no texture found"))
        : Texture(textureId: _textureId);
  }
}

// --------------------------------------------------------------
// progress indicator
// --------------------------------------------------------------

class VideoProgressColors {
  final Color playedColor;
  final Color bufferedColor;
  final Color backgroundColor;

  VideoProgressColors({
    this.playedColor = const Color.fromRGBO(255, 0, 0, 0.7),
    this.bufferedColor = const Color.fromRGBO(50, 50, 200, 0.2),
    this.backgroundColor = const Color.fromRGBO(200, 200, 200, 0.5),
  });
}

class _VideoScrubber extends StatefulWidget {
  final Widget child;
  final AsunaVideoPlayerController controller;

  _VideoScrubber({@required this.child, @required this.controller});

  @override
  State<StatefulWidget> createState() => _VideoScrubberState();
}

class _VideoScrubberState extends State<_VideoScrubber> {
  bool _controllerWasPlaying = false;

  AsunaVideoPlayerController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    void seekToRelativePosition(Offset globalPosition) {
      final RenderBox box = context.findRenderObject();
      final Offset tapPos = box.globalToLocal(globalPosition);
      final double relative = tapPos.dx / box.size.width;
      final Duration position = controller.value.duration * relative;
      controller.seekTo(position);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: widget.child,
      onHorizontalDragStart: (DragStartDetails details) {
        if (!controller.value.initialized) {
          return;
        }
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
        if (_controllerWasPlaying) {
          controller.play();
        }
      },
      onTapDown: (TapDownDetails details) {
        if (!controller.value.initialized) {
          return;
        }
        seekToRelativePosition(details.globalPosition);
      },
    );
  }
}

/// Displays the play/buffering status of the video controlled by [controller].
///
/// If [allowScrubbing] is true, this widget will detect taps and drags and
/// seek the video accordingly.
///
/// [padding] allows to specify some extra padding around the progress indicator
/// that will also detect the gestures.
class VideoProgressIndicator extends StatefulWidget {
  final AsunaVideoPlayerController controller;
  final VideoProgressColors colors;
  final bool allowScrubbing;
  final EdgeInsets padding;

  VideoProgressIndicator(
    this.controller, {
    VideoProgressColors colors,
    this.allowScrubbing,
    this.padding = const EdgeInsets.only(top: 12.0, bottom: 9.0),
  }) : colors = colors ?? VideoProgressColors();

  @override
  State<StatefulWidget> createState() => _VideoProgressIndicatorState();
}

class _VideoProgressIndicatorState extends State<VideoProgressIndicator> {
  VoidCallback listener;

  _VideoProgressIndicatorState() {
    listener = () {
      if (!mounted || !controller.value.isPlaying) {
        return;
      }
      setState(() {});
    };
  }

  AsunaVideoPlayerController get controller => widget.controller;
  VideoProgressColors get colors => widget.colors;

  @override
  void initState() {
    super.initState();
    controller.addListener(listener);
  }

  @override
  void deactivate() {
    controller.removeListener(listener);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    Widget progressIndicator;
    if (controller.value.initialized) {
      final int duration = controller.value.duration.inMilliseconds;
      final int position = controller.value.position.inMilliseconds;

      int maxBuffering = 0;
      for (DurationRange range in controller.value.buffered) {
        final int end = range.end.inMilliseconds;
        if (end > maxBuffering) {
          maxBuffering = end;
        }
      }

      progressIndicator = Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          LinearProgressIndicator(
            value: maxBuffering / duration,
            valueColor: AlwaysStoppedAnimation<Color>(colors.bufferedColor),
            backgroundColor: colors.backgroundColor,
          ),
          LinearProgressIndicator(
            value: position / duration,
            valueColor: AlwaysStoppedAnimation<Color>(colors.playedColor),
            backgroundColor: Colors.transparent,
          ),
        ],
      );
    } else {
      progressIndicator = LinearProgressIndicator(
        value: null,
        valueColor: AlwaysStoppedAnimation<Color>(colors.playedColor),
        backgroundColor: colors.backgroundColor,
      );
    }

    final Widget paddedProgressIndicator = Padding(
      padding: widget.padding,
      child: progressIndicator,
    );

    if (widget.allowScrubbing) {
      return _VideoScrubber(
        child: paddedProgressIndicator,
        controller: controller,
      );
    } else {
      return paddedProgressIndicator;
    }
  }
}
