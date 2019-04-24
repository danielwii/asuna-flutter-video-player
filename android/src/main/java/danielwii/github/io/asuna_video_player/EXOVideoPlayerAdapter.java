package danielwii.github.io.asuna_video_player;

import android.content.Context;
import android.net.Uri;
import android.os.Build;
import android.util.Log;
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
import io.flutter.plugin.common.MethodChannel;
import io.flutter.view.TextureRegistry;

public class EXOVideoPlayerAdapter implements IAsunaVideoPlayer {
    private static final String TAG = EXOVideoPlayerAdapter.class.getSimpleName();

    private SimpleExoPlayer                     exoPlayer;
    private EventChannel                        eventChannel;
    private QueuingEventSink                    eventSink     = new QueuingEventSink();
    private TextureRegistry.SurfaceTextureEntry textureEntry;
    private Surface                             surface;
    private boolean                             isInitialized = false;

    EXOVideoPlayerAdapter(
            Context context,
            EventChannel eventChannel,
            TextureRegistry.SurfaceTextureEntry textureEntry,
            String dataSource,
            MethodChannel.Result result) {
        this.eventChannel = eventChannel;
        this.textureEntry = textureEntry;

        Log.d(TAG, "create simple exo-player...");
        DefaultTrackSelector trackSelector = new DefaultTrackSelector();
        exoPlayer = ExoPlayerFactory.newSimpleInstance(context, trackSelector);

        Uri uri = Uri.parse(dataSource);

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

        setupVideoPlayer(eventChannel, textureEntry, result);
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
            Uri uri, DataSource.Factory mediaDataSourceFactory, Context context) {
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
                /*
                DefaultExtractorsFactory extractorsFactory = new DefaultExtractorsFactory();
                extractorsFactory.setTsExtractorFlags(DefaultTsPayloadReaderFactory.FLAG_ALLOW_NON_IDR_KEYFRAMES);*/
                return new ExtractorMediaSource.Factory(mediaDataSourceFactory)
                        .setExtractorsFactory(new DefaultExtractorsFactory())
                        .createMediaSource(uri);
            default:
                throw new IllegalStateException("Unsupported type: " + type);
        }
    }

    private void setupVideoPlayer(
            EventChannel eventChannel,
            TextureRegistry.SurfaceTextureEntry textureEntry,
            MethodChannel.Result result) {
        Log.d(TAG, "exo-player setupVideoPlayer..." + textureEntry.id());
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink sink) {
                Log.d(TAG, "eventChannel.onListen: " + sink);
                eventSink.setDelegate(sink);
            }

            @Override
            public void onCancel(Object arguments) { eventSink.setDelegate(null); }
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
                    eventSink.success(event);
                } else if (playbackState == Player.STATE_READY) {
                    if (!isInitialized) {
                        isInitialized = true;
                        sendInitialized();
                    }
                } else if (playbackState == Player.STATE_ENDED) {
                    Map<String, Object> event = new HashMap<>();
                    event.put("event", "completed");
                    eventSink.success(event);
                }
            }

            @Override
            public void onPlayerError(ExoPlaybackException error) {
                if (eventSink != null) {
                    eventSink.error("VideoError", "Video player had error: " + error, null);
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
