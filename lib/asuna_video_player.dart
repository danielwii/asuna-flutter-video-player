import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef void EventHandler(Object event);

final MethodChannel _channel = const MethodChannel('asuna_video_player')..invokeMethod("init");

class AsunaVideoPlayer extends StatefulWidget {
  final AsunaVideoPlayerController controller;
  static const EventChannel _status_channel = const EventChannel('asuna_video_player.event.status');
  static const EventChannel _position_channel =
      const EventChannel('asuna_video_player.event.position');
  static const EventChannel _spectrum_channel =
      const EventChannel('asuna_video_player.event.spectrum');

  const AsunaVideoPlayer(this.controller);

//  static Future<void> open() async {
//    await _channel.invokeMethod('open');
//  }
//
//  static Future<void> pause() async {
//    await _channel.invokeMethod('pause');
//  }
//
//  static Future<void> start() async {
//    await _channel.invokeMethod('start');
//  }

  Future<void> startDemo() async {
    controller.initialize();
  }

  static Future<Duration> get duration async {
    int duration = await _channel.invokeMethod('getDuration');
    return Duration(milliseconds: duration);
  }

  static listenStatus(EventHandler onEvent, EventHandler onError) {
    _status_channel.receiveBroadcastStream().listen(onEvent, onError: onError);
  }

  static listenPosition(EventHandler onEvent, EventHandler onError) {
    _position_channel.receiveBroadcastStream().listen(onEvent, onError: onError);
  }

  static listenSpectrum(EventHandler onEvent, EventHandler onError) {
    _spectrum_channel.receiveBroadcastStream().listen(onEvent, onError: onError);
  }

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

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
    widget.controller.removeListener(_listener);
  }

  @override
  Widget build(BuildContext context) => _textureId == null
      ? Container(child: Text("no texture found"))
      : Texture(textureId: _textureId);
}

class AsunaVideoPlayerController extends ValueNotifier<_AsunaVideoPlayerValue> {
  int _textureId;
  bool _isDisposed = false;
  Timer _timer;
  StreamSubscription<dynamic> _eventSubscription;
  final String dataSource;

//  AsunaVideoPlayerController.instance() : super(_AsunaVideoPlayerValue(duration: null));
  AsunaVideoPlayerController.network(this.dataSource)
      : super(_AsunaVideoPlayerValue(duration: null));

  int get textureId => _textureId;

  Future<void> initialize() async {
    print('AsunaVideoPlayerController.initialize $dataSource');
    // TODO: remove this on when the invokeMethod update makes it to stable Flutter.
    // https://github.com/flutter/flutter/issues/26431
    // ignore: strong_mode_implicit_dynamic_method
    final Map<dynamic, dynamic> response = await _channel.invokeMethod("create", {
      "title": "测试视频",
      "source": dataSource,
    });

    print(response);
    _textureId = response['textureId'];
    final Completer<void> initializingCompleter = Completer<void>();
    DurationRange toDurationRange(dynamic value) {
      final List<dynamic> pair = value;
      return DurationRange(Duration(milliseconds: pair[0]), Duration(milliseconds: pair[1]));
    }

    void eventListener(dynamic event) {
      print(event);

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

//    _channel.invokeMethod("play", {"textureId": _textureId});
    return initializingCompleter.future;
  }

  EventChannel _eventChannelFor(int textureId) =>
      EventChannel('asuna_video_player/videoEvents$textureId');

  Future<void> setLooping(bool looping) async {
    value = value.copyWith(isLooping: looping);
  }

  Future<Duration> get position async {
    if (_isDisposed) {
      return null;
    }
    return Duration(
      // TODO: remove this on when the invokeMethod update makes it to stable Flutter.
      // https://github.com/flutter/flutter/issues/26431
      // ignore: strong_mode_implicit_dynamic_method
      milliseconds:
          await _channel.invokeMethod('position', <String, dynamic>{'textureId': textureId}),
    );
  }

  Future<void> _applyPlayPause() async {
    if (!value.initialized || _isDisposed) {
      return;
    }
    if (value.isPlaying) {
      await _channel.invokeMethod('play', <String, dynamic>{'textureId': _textureId});
      _timer = Timer.periodic(const Duration(milliseconds: 500), (Timer timer) async {
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
      // TODO: remove this on when the invokeMethod update makes it to stable Flutter.
      // https://github.com/flutter/flutter/issues/26431
      // ignore: strong_mode_implicit_dynamic_method
      await _channel.invokeMethod('pause', <String, dynamic>{'textureId': _textureId});
    }
  }

  Future<void> play() async {
    value = value.copyWith(isPlaying: true);
    await _applyPlayPause();
  }

  Future<void> pause() async {
    value = value.copyWith(isPlaying: false);
    await _applyPlayPause();
  }

  Future<void> _applyVolume() async {
    if (!value.initialized || _isDisposed) {
      return;
    }
    // TODO: remove this on when the invokeMethod update makes it to stable Flutter.
    // https://github.com/flutter/flutter/issues/26431
    // ignore: strong_mode_implicit_dynamic_method
    await _channel.invokeMethod(
        'setVolume', <String, dynamic>{'textureId': _textureId, 'volume': value.volume});
  }

  Future<void> _applyLooping() async {
    if (!value.initialized || _isDisposed) {
      return;
    }
    // TODO: remove this on when the invokeMethod update makes it to stable Flutter.
    // https://github.com/flutter/flutter/issues/26431
    // ignore: strong_mode_implicit_dynamic_method
    _channel.invokeMethod(
        'setLooping', <String, dynamic>{'textureId': _textureId, 'looping': value.isLooping});
  }
}

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
