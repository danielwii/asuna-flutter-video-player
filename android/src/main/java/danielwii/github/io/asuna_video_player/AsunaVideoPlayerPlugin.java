package danielwii.github.io.asuna_video_player;

import android.annotation.TargetApi;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.util.Log;
import android.util.LongSparseArray;
import android.view.Surface;

import com.google.android.exoplayer2.C;
import com.google.android.exoplayer2.ExoPlaybackException;
import com.google.android.exoplayer2.ExoPlayerFactory;
import com.google.android.exoplayer2.Format;
import com.google.android.exoplayer2.Player;
import com.google.android.exoplayer2.SimpleExoPlayer;
import com.google.android.exoplayer2.audio.AudioAttributes;
import com.google.android.exoplayer2.extractor.DefaultExtractorsFactory;
import com.google.android.exoplayer2.extractor.ts.DefaultTsPayloadReaderFactory;
import com.google.android.exoplayer2.source.ExtractorMediaSource;
import com.google.android.exoplayer2.source.MediaSource;
import com.google.android.exoplayer2.source.dash.DashMediaSource;
import com.google.android.exoplayer2.source.dash.DefaultDashChunkSource;
import com.google.android.exoplayer2.source.hls.HlsMediaSource;
import com.google.android.exoplayer2.source.smoothstreaming.DefaultSsChunkSource;
import com.google.android.exoplayer2.source.smoothstreaming.SsMediaSource;
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector;
import com.google.android.exoplayer2.upstream.DataSource;
import com.google.android.exoplayer2.upstream.DefaultDataSourceFactory;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSourceFactory;
import com.google.android.exoplayer2.util.Util;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;

import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugin.common.PluginRegistry.Registrar;
import io.flutter.view.FlutterNativeView;
import io.flutter.view.TextureRegistry;

import static android.app.Activity.RESULT_OK;

/**
 * AsunaVideoPlayerPlugin
 */
@TargetApi(Build.VERSION_CODES.M)
public class AsunaVideoPlayerPlugin implements
        MethodCallHandler,
        PluginRegistry.ViewDestroyListener
//        PluginRegistry.RequestPermissionsResultListener,
//        PluginRegistry.ActivityResultListener
{
    private static final String TAG = AsunaVideoPlayerPlugin.class.getSimpleName();

    static enum VideoType {
        IJK_PLAYER,
        EXO_PLAYER,
    }

    private interface IAsunaVideoPlayer {
//        void setupVideoPlayer(
//                EventChannel eventChannel,
//                TextureRegistry.SurfaceTextureEntry textureEntry,
//                Result result);

        void setDataSource(String dataSource);

        void play();

        void pause();

        void setLooping(boolean looping);

        void setVolume(double value);

        void seekTo(int location);

        long getPosition();

        void dispose();
    }

    private static class AsunaVideoPlayerManager {
        private       IAsunaVideoPlayer                   videoPlayer;
        private       Surface                             surface;
        private final TextureRegistry.SurfaceTextureEntry textureEntry;
        private       QueuingEventSink                    queuingEventSink = new QueuingEventSink();
        private final EventChannel                        eventChannel;
        private       boolean                             isInitialized    = false;

        private AsunaVideoPlayerManager(
                Context context,
                VideoType videoType,
                EventChannel eventChannel,
                TextureRegistry.SurfaceTextureEntry textureEntry,
                Result result) {
            Log.d(TAG, "AsunaVideoPlayer: constructor");
            this.eventChannel = eventChannel;
            this.textureEntry = textureEntry;

            switch (videoType) {
//                case IJK_PLAYER:
//                    this.videoPlayer = new IJKVideoPlayerAdapter(context);
//                    break;
                case EXO_PLAYER:
                    this.videoPlayer = new EXOVideoPlayerAdapter(context, eventChannel, queuingEventSink, textureEntry, result);
                    break;
                default:
                    throw new IllegalStateException("Unsupported video type: " + videoType);
            }
        }

        IAsunaVideoPlayer instance() {
            return videoPlayer;
        }

    }

    private static class EXOVideoPlayerAdapter implements IAsunaVideoPlayer {
        private SimpleExoPlayer                     exoPlayer;
        private Context                             context;
        private EventChannel                        eventChannel;
        private QueuingEventSink                    eventSink;
        private TextureRegistry.SurfaceTextureEntry textureEntry;
        private Result                              result;
        private Surface                             surface;
        private boolean                             isInitialized = false;

        EXOVideoPlayerAdapter(
                Context context,
                EventChannel eventChannel,
                QueuingEventSink eventSink,
                TextureRegistry.SurfaceTextureEntry textureEntry,
                Result result) {
            this.context = context;
            this.eventChannel = eventChannel;
            this.eventSink = eventSink;
            this.textureEntry = textureEntry;
            this.result = result;

            Log.d(TAG, "create simple exo-player...");
            DefaultTrackSelector trackSelector = new DefaultTrackSelector();
            exoPlayer = ExoPlayerFactory.newSimpleInstance(context, trackSelector);

            setupVideoPlayer(eventChannel, eventSink, textureEntry, result);
        }

        @Override
        public void setDataSource(String dataSource) {
            Uri                uri = Uri.parse(dataSource);
            DataSource.Factory dataSourceFactory;
            if (Objects.equals(uri.getScheme(), "asset") || Objects.equals(uri.getScheme(), "file")) {
                dataSourceFactory = new DefaultDataSourceFactory(context, "ExoPlayer");
            } else {
                dataSourceFactory = new DefaultHttpDataSourceFactory(
                        "ExoPlayer",
                        null,
                        DefaultHttpDataSource.DEFAULT_CONNECT_TIMEOUT_MILLIS,
                        DefaultHttpDataSource.DEFAULT_READ_TIMEOUT_MILLIS,
                        true);
            }

            MediaSource mediaSource = buildMediaSource(uri, dataSourceFactory, context);
            exoPlayer.prepare(mediaSource);
        }

        @Override
        public void play() {
            exoPlayer.setPlayWhenReady(true);
        }

        @Override
        public void pause() {
            exoPlayer.setPlayWhenReady(false);
        }

        @Override
        public void setLooping(boolean looping) {
            exoPlayer.setRepeatMode(looping ? Player.REPEAT_MODE_ALL : Player.REPEAT_MODE_OFF);
        }

        @Override
        public void setVolume(double value) {
            float bracketedValue = (float) Math.max(0.0, Math.min(1.0, value));
            exoPlayer.setVolume(bracketedValue);
        }

        @Override
        public void seekTo(int location) {
            exoPlayer.seekTo(location);
        }

        @Override
        public long getPosition() {
            return exoPlayer.getCurrentPosition();
        }

        @Override
        public void dispose() {
            if (isInitialized) {
                exoPlayer.stop();
            }
            textureEntry.release();
            eventChannel.setStreamHandler(null);
            if (surface != null) {
                surface.release();
            }
            if (exoPlayer != null) {
                exoPlayer.release();
            }
        }

        private MediaSource buildMediaSource(
                Uri uri,
                DataSource.Factory mediaDataSourceFactory,
                Context context) {
            int type = Util.inferContentType(uri.getLastPathSegment());
            Log.d(TAG, "generate media-source by type " + type);
            switch (type) {
                case C.TYPE_SS:
                    return new SsMediaSource.Factory(
                            new DefaultSsChunkSource.Factory(mediaDataSourceFactory),
                            new DefaultDataSourceFactory(context, null, mediaDataSourceFactory)
                    ).createMediaSource(uri);
                case C.TYPE_DASH:
                    return new DashMediaSource.Factory(
                            new DefaultDashChunkSource.Factory(mediaDataSourceFactory),
                            new DefaultDataSourceFactory(context, null, mediaDataSourceFactory)
                    ).createMediaSource(uri);
                case C.TYPE_HLS:
                    return new HlsMediaSource.Factory(mediaDataSourceFactory).createMediaSource(uri);
                case C.TYPE_OTHER:
                    DefaultExtractorsFactory extractorsFactory = new DefaultExtractorsFactory();
                    extractorsFactory.setTsExtractorFlags(DefaultTsPayloadReaderFactory.FLAG_ALLOW_NON_IDR_KEYFRAMES);
                    return new ExtractorMediaSource.Factory(mediaDataSourceFactory)
                            .setExtractorsFactory(extractorsFactory)
                            .createMediaSource(uri);
                default:
                    throw new IllegalStateException("Unsupported type: " + type);
            }
        }

        private void setupVideoPlayer(
                EventChannel eventChannel,
                final QueuingEventSink queuingEventSink,
                TextureRegistry.SurfaceTextureEntry textureEntry,
                Result result) {
            Log.d(TAG, "exo-player setupVideoPlayer..." + textureEntry.id());
            eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
                @Override
                public void onListen(Object arguments, EventChannel.EventSink events) {
                    Log.d(TAG, "eventChannel.onListen: " + events);
                    queuingEventSink.setDelegate(events);
                }

                @Override
                public void onCancel(Object arguments) { queuingEventSink.setDelegate(null); }
            });

            Log.d(TAG, "exo-player setupVideoPlayer... create surface...");
            surface = new Surface(textureEntry.surfaceTexture());
            exoPlayer.setVideoSurface(surface);
            Log.d(TAG, "exo-player setupVideoPlayer... setup audio attributes...");
            setAudioAttributes(exoPlayer);

            exoPlayer.addListener(new Player.EventListener() {
                @Override
                public void onPlayerStateChanged(boolean playWhenReady, int playbackState) {
                    if (playbackState == Player.STATE_BUFFERING) {
                        Map<String, Object> event = new HashMap<>();
                        event.put("event", "bufferingUpdate");
                        List<Integer> range = Arrays.asList(0, exoPlayer.getBufferedPercentage());
                        // iOS supports a list of buffered ranges, so here is a list with a single range.
                        event.put("values", Collections.singletonList(range));
                        queuingEventSink.success(event);
                    } else if (playbackState == Player.STATE_READY && !isInitialized) {
                        isInitialized = true;
                        sendInitialized();
                    }
                }

                @Override
                public void onPlayerError(ExoPlaybackException error) {
                    if (queuingEventSink != null) {
                        queuingEventSink.error("VideoError", "Video player had error: " + error, null);
                    }
                }
            });

            Log.d(TAG, "exo-player setupVideoPlayer... send reply...");
            Map<String, Object> reply = new HashMap<>();
            reply.put("textureId", textureEntry.id());
            result.success(reply);
        }

        @SuppressWarnings("deprecation")
        private static void setAudioAttributes(SimpleExoPlayer player) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                player.setAudioAttributes(
                        new AudioAttributes.Builder().setContentType(C.CONTENT_TYPE_MOVIE).build());
            } else {
                player.setAudioStreamType(C.STREAM_TYPE_MUSIC);
            }
        }

        private void sendInitialized() {
            if (isInitialized) {
                Map<String, Object> event = new HashMap<>();
                event.put("event", "initialized");
                event.put("duration", exoPlayer.getDuration());

                if (exoPlayer.getVideoFormat() != null) {
                    Format videoFormat     = exoPlayer.getVideoFormat();
                    int    width           = videoFormat.width;
                    int    height          = videoFormat.height;
                    int    rotationDegrees = videoFormat.rotationDegrees;
                    // Switch the width/height if video was taken in portrait mode
                    if (rotationDegrees == 90 || rotationDegrees == 270) {
                        width = exoPlayer.getVideoFormat().height;
                        height = exoPlayer.getVideoFormat().width;
                    }
                    event.put("width", width);
                    event.put("height", height);
                }
                eventSink.success(event);
            }
        }
    }

    private static final String PLUGIN_NAME                        = "asuna_video_player";
    private static final String PLAYER_EVENT_STATUS_CHANNEL_NAME   = PLUGIN_NAME + ".event.status";
    private static final String PLAYER_EVENT_POSITION_CHANNEL_NAME = PLUGIN_NAME + ".event.position";
    private static final String PLAYER_EVENT_SPECTRUM_CHANNEL_NAME = PLUGIN_NAME + ".event.spectrum";

    private static final int PERMISSIONS_REQUEST_RECORD_AUDIO           = 1001;
    private static final int PERMISSIONS_REQUEST_READ_STORAGE           = 1002;
    private static final int PERMISSIONS_REQUEST_WRITE_EXTERNAL_STORAGE = 1110;

    private static final int REQUEST_CODE_OPEN = 12345;

    private Handler  mHandler          = new Handler();
    private Runnable mPositionReporter = new Runnable() {
        @Override
        public void run() {
//            if (mMediaPlayer != null && mMediaPlayer.isPlaying()) {
//                mPositionSink.success(mMediaPlayer.getCurrentPosition());
//                mHandler.postDelayed(mPositionReporter, 500);
//            }
        }
    };

    private final LongSparseArray<IAsunaVideoPlayer> mVideoPlayers;
    private final Registrar                          mRegistrar;

    private EventChannel.EventSink mStateSink;
    private EventChannel.EventSink mPositionSink;
    private EventChannel.EventSink mSpectrumSink;

    private AsunaVideoPlayerPlugin(Registrar registrar) {
        Log.d(TAG, "init with activity..." + Build.VERSION.SDK_INT + "/" + Build.VERSION_CODES.M);
        mRegistrar = registrar;
        mVideoPlayers = new LongSparseArray<>();
//        mVideoPlayers = new HashMap<>();
//        if (mActivity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
//            mActivity.requestPermissions(new String[] { Manifest.permission.RECORD_AUDIO }, PERMISSIONS_REQUEST_RECORD_AUDIO);
//        }
    }

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        Log.d(TAG, "register...");
        final AsunaVideoPlayerPlugin plugin = new AsunaVideoPlayerPlugin(registrar);
        registrar.addViewDestroyListener(plugin);
//        registrar.addActivityResultListener(plugin);
//        registrar.addRequestPermissionsResultListener(plugin);

        final MethodChannel channel = new MethodChannel(registrar.messenger(), PLUGIN_NAME);
        channel.setMethodCallHandler(plugin);
/*
        // send player status
        Log.d(TAG, "create channel " + PLAYER_EVENT_STATUS_CHANNEL_NAME);
        EventChannel statusChannel = new EventChannel(registrar.messenger(), PLAYER_EVENT_STATUS_CHANNEL_NAME);
        statusChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                Log.d(TAG, "setup status channel...");
                plugin.setStateSink(events);
            }

            @Override
            public void onCancel(Object o) { }
        });

        Log.d(TAG, "create channel " + PLAYER_EVENT_POSITION_CHANNEL_NAME);
        EventChannel positionChannel = new EventChannel(registrar.messenger(), PLAYER_EVENT_POSITION_CHANNEL_NAME);
        positionChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                Log.d(TAG, "setup position channel...");
                plugin.setPositionSink(events);
            }

            @Override
            public void onCancel(Object arguments) { }
        });

        Log.d(TAG, "create channel " + PLAYER_EVENT_SPECTRUM_CHANNEL_NAME);
        EventChannel spectrumChannel = new EventChannel(registrar.messenger(), PLAYER_EVENT_SPECTRUM_CHANNEL_NAME);
        spectrumChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                Log.d(TAG, "setup spectrum channel...");
                plugin.setSpectrumSink(events);
            }

            @Override
            public void onCancel(Object arguments) { }
        });
*/
    }

/*
    private void setStateSink(EventChannel.EventSink stateSink) {
        Log.d(TAG, "set status channel...");
        mStateSink = stateSink;
    }

    private void setPositionSink(EventChannel.EventSink positionSink) {
        Log.d(TAG, "set position channel...");
        mPositionSink = positionSink;
    }

    private void setSpectrumSink(EventChannel.EventSink spectrumSink) {
        Log.d(TAG, "set spectrum channel...");
        mSpectrumSink = spectrumSink;
    }
*/

    private void init(MethodCall call, Result result) {
        Log.d(TAG, "init...");
        onDestroy();
    }

    private void create(MethodCall call, Result result, TextureRegistry.SurfaceTextureEntry surfaceTexture, String source, String title) {
        Log.d(TAG, "create..." + "source is " + source + ", title is " + title);

        EventChannel eventChannel =
                new EventChannel(mRegistrar.messenger(), PLUGIN_NAME + "/videoEvents" + surfaceTexture.id());

        IAsunaVideoPlayer videoPlayer;

        // TODO handle uri only for now
        videoPlayer = new AsunaVideoPlayerManager(
                mRegistrar.context(),
                VideoType.EXO_PLAYER,
                eventChannel,
                surfaceTexture,
                result
        ).instance();
        videoPlayer.setDataSource(source);
//        videoPlayer.setDataSource((String) call.argument("uri"));
        mVideoPlayers.put(surfaceTexture.id(), videoPlayer);
    }

    private void onDestroy() {
        // The whole FlutterView is being destroyed. Here we release resources acquired for all instances
        // of VideoPlayer. Once https://github.com/flutter/flutter/issues/19358 is resolved this may
        // be replaced with just asserting that videoPlayers.isEmpty().
        // https://github.com/flutter/flutter/issues/20989 tracks this.
        for (int i = 0; i < mVideoPlayers.size(); i++) {
            long key = mVideoPlayers.keyAt(i);
            mVideoPlayers.get(key).dispose();
        }
        mVideoPlayers.clear();
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        Log.d(TAG, "onMethodCall:" + call.method + ", " + call.arguments);
        if (call.method.equals("getPlatformVersion")) {
            result.success("Android " + android.os.Build.VERSION.RELEASE);
        } else {
            TextureRegistry textures = mRegistrar.textures();
            if (textures == null) {
                result.error("no_activity", "asuna_video_player plugin requires a foreground activity", null);
                return;
            }

            switch (call.method) {
                case "init": {
                    init(call, result);
                    break;
                }
                case "create": {
                    create(call, result,
                            textures.createSurfaceTexture(),
                            Objects.requireNonNull(call.argument("source")).toString(),
                            Objects.requireNonNull(call.argument("title")).toString());
                    break;
                }
//                case "pause":
//                    mMediaPlayer.pause();
//                    mVisualizer.setEnabled(false);
//                    mHandler.removeCallbacks(mPositionReporter);
//                    mStateSink.success("paused");
//                    break;
//                case "start":
//                    mMediaPlayer.start();
//                    mVisualizer.setEnabled(true);
//                    mStateSink.success("started");
//                    mHandler.postDelayed(mPositionReporter, 500);
//                    break;
//                case "open":
//                    Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
//                    intent.addCategory(Intent.CATEGORY_OPENABLE);
//                    intent.setType("audio/*");
//                    mActivity.startActivityForResult(intent, REQUEST_CODE_OPEN);
//                    break;
//                case "getDuration":
//                    if (mMediaPlayer != null) {
//                        result.success(mMediaPlayer.getDuration());
//                    } else {
//                        result.error("ERROR", "no valid media player", null);
//                    }
//                    break;
                default: {
                    long              textureId   = ((Number) Objects.requireNonNull(call.argument("textureId"))).longValue();
                    IAsunaVideoPlayer videoPlayer = mVideoPlayers.get(textureId);
                    if (videoPlayer == null) {
                        result.error(
                                "Unknown textureId",
                                "No video player associated with texture id " + textureId,
                                null);
                        return;
                    }

                    onMethodCall(call, result, textureId, videoPlayer);

                    break;
                }
            }
        }
    }

    private void onMethodCall(
            MethodCall call,
            Result result,
            long textureId,
            IAsunaVideoPlayer player) {
        switch (call.method) {
            case "setLooping":
                player.setLooping(((boolean) call.argument("looping")));
                result.success(null);
                break;
            case "setVolume":
                player.setVolume((double) call.argument("volume"));
                result.success(null);
                break;
            case "play":
                player.play();
                result.success(null);
                break;
            case "pause":
                player.pause();
                result.success(null);
                break;
            case "seekTo":
                int location = ((Number) Objects.requireNonNull(call.argument("location"))).intValue();
                player.seekTo(location);
                result.success(null);
                break;
            case "position":
                result.success(player.getPosition());
                break;
            case "dispose":
                player.dispose();
                mVideoPlayers.remove(textureId);
                result.success(null);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

/*
    @Override
    public boolean onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        switch (requestCode) {
            case PERMISSIONS_REQUEST_RECORD_AUDIO:
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    if (mActivity.checkSelfPermission(Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                        mActivity.requestPermissions(new String[] { Manifest.permission.READ_EXTERNAL_STORAGE }, PERMISSIONS_REQUEST_READ_STORAGE);
                    }
                    return true;
                }
                mActivity.finish();
                return false;
            case PERMISSIONS_REQUEST_READ_STORAGE:
                if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    return true;
                }
                mActivity.finish();
                return false;
            default:
                return false;
        }
    }
*/

    @Override
    public boolean onViewDestroy(FlutterNativeView view) {
        onDestroy();
        return false; // We are not interested in assuming ownership of the NativeView.
    }

/*
    @Override
    public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQUEST_CODE_OPEN && resultCode == RESULT_OK) {
            Uri uri = data.getData();
            if (uri != null) {
                Log.d(TAG, "opening" + uri);
                play(uri);
            } else {
                mStateSink.error("ERROR", "invalid media file", null);
            }
            return true;
        }
        return false;
    }
*/
}
