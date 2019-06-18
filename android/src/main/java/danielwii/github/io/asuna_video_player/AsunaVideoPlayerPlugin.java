package danielwii.github.io.asuna_video_player;

import android.annotation.TargetApi;
import android.content.Context;
import android.os.Build;
import android.security.NetworkSecurityPolicy;
import android.util.Log;
import android.util.LongSparseArray;
import android.view.Surface;

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
import timber.log.Timber;

/**
 * AsunaVideoPlayerPlugin
 */
public class AsunaVideoPlayerPlugin implements MethodCallHandler {
    private static final String TAG = AsunaVideoPlayerPlugin.class.getSimpleName();

    enum PlayerType {
        IJK_PLAYER("ijk"),
        EXO_PLAYER("exo"),
        ;

        private String name;

        PlayerType(String name) {
            this.name = name;
        }

        static PlayerType of(String name) {
            for (PlayerType type :
                    values()) {
                if (Objects.equals(type.name, name)) return type;
            }
            return PlayerType.EXO_PLAYER;
        }
    }

    private static class AsunaVideoPlayerManager {
        private final IAsunaVideoPlayer                   videoPlayer;
        private       Surface                             surface;
        private final TextureRegistry.SurfaceTextureEntry textureEntry;
        private final EventChannel                        eventChannel;
        private       boolean                             isInitialized = false;

        private AsunaVideoPlayerManager(
                Context context,
                PlayerType playerType,
                EventChannel eventChannel,
                TextureRegistry.SurfaceTextureEntry textureEntry,
                String dataSource,
                Result result) {
            this.eventChannel = eventChannel;
            this.textureEntry = textureEntry;

            switch (playerType) {
//                case IJK_PLAYER:
//                    this.videoPlayer = new IJKVideoPlayerAdapter(context);
//                    break;
                case EXO_PLAYER:
                    this.videoPlayer = new EXOVideoPlayerAdapter(
                            context, eventChannel, textureEntry, dataSource, result);
                    break;
                default:
                    throw new IllegalStateException("Unsupported player type: " + playerType);
            }
        }

        IAsunaVideoPlayer instance() {
            return videoPlayer;
        }
    }

    private static final String PLUGIN_NAME = "asuna_video_player";

    private static final int PERMISSIONS_REQUEST_RECORD_AUDIO           = 1001;
    private static final int PERMISSIONS_REQUEST_READ_STORAGE           = 1002;
    private static final int PERMISSIONS_REQUEST_WRITE_EXTERNAL_STORAGE = 1110;

    private static final int REQUEST_CODE_OPEN = 12345;

    private final LongSparseArray<IAsunaVideoPlayer> mVideoPlayers;
    private final Registrar                          mRegistrar;


    private AsunaVideoPlayerPlugin(Registrar registrar) {
        if (BuildConfig.DEBUG) {
            Timber.plant(new Timber.DebugTree());
        }
        Timber.tag(TAG).d("init with activity...%d/%d", Build.VERSION.SDK_INT, Build.VERSION_CODES.M);
        mRegistrar = registrar;
        mVideoPlayers = new LongSparseArray<>();
//        if (mActivity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
//            mActivity.requestPermissions(new String[] { Manifest.permission.RECORD_AUDIO }, PERMISSIONS_REQUEST_RECORD_AUDIO);
//        }
    }

    public static void registerWith(Registrar registrar) {
        Timber.tag(TAG).d("register...");
        final AsunaVideoPlayerPlugin plugin = new AsunaVideoPlayerPlugin(registrar);

        final MethodChannel channel = new MethodChannel(registrar.messenger(), PLUGIN_NAME);
        channel.setMethodCallHandler(plugin);

        registrar.addViewDestroyListener(new PluginRegistry.ViewDestroyListener() {
            @Override
            public boolean onViewDestroy(FlutterNativeView flutterNativeView) {
                plugin.onDestroy();
                return false; // We are not interested in assuming ownership of the NativeView.
            }
        });
    }

    private void create(
            MethodCall call,
            Result result,
            TextureRegistry.SurfaceTextureEntry surfaceTexture) {
        Timber.tag(TAG).d("create... type is %s", call.<String>argument("type"));

        EventChannel eventChannel =
                new EventChannel(mRegistrar.messenger(), PLUGIN_NAME + "/videoEvents" + surfaceTexture.id());

        IAsunaVideoPlayer player;

        if (call.argument("asset") != null) {
            String assetLookupKey;
            if (call.argument("package") != null) {
                assetLookupKey = mRegistrar.lookupKeyForAsset(
                        call.<String>argument("asset"),
                        call.<String>argument("package"));
            } else {
                assetLookupKey = mRegistrar.lookupKeyForAsset(call.<String>argument("asset"));
            }
            player = new AsunaVideoPlayerManager(
                    mRegistrar.context(),
                    PlayerType.of(call.<String>argument("type")),
                    eventChannel,
                    surfaceTexture,
                    "asset:///" + assetLookupKey,
                    result
            ).instance();
        } else {
            player = new AsunaVideoPlayerManager(
                    mRegistrar.context(),
                    PlayerType.EXO_PLAYER,
                    eventChannel,
                    surfaceTexture,
                    call.<String>argument("uri"),
                    result
            ).instance();
        }

        mVideoPlayers.put(surfaceTexture.id(), player);
    }

    private void onDestroy() {
        // The whole FlutterView is being destroyed. Here we release resources acquired for all instances
        // of VideoPlayer. Once https://github.com/flutter/flutter/issues/19358 is resolved this may
        // be replaced with just asserting that videoPlayers.isEmpty().
        // https://github.com/flutter/flutter/issues/20989 tracks this.
        for (int i = 0; i < mVideoPlayers.size(); i++) {
            mVideoPlayers.valueAt(i).dispose();
        }
        mVideoPlayers.clear();
    }

    @Override
    public void onMethodCall(MethodCall call, Result result) {
        Timber.tag(TAG).d("onMethodCall:%s, %s", call.method, call.arguments);
        TextureRegistry textures = mRegistrar.textures();
        if (textures == null) {
            result.error("no_activity", "asuna_video_player plugin requires a foreground activity", null);
            return;
        }

        switch (call.method) {
            case "init": {
                onDestroy();
                break;
            }
            case "create": {
                create(call, result, textures.createSurfaceTexture());
                break;
            }
            default: {
                long              textureId = ((Number) Objects.requireNonNull(call.argument("textureId"))).longValue();
                IAsunaVideoPlayer player    = mVideoPlayers.get(textureId);
                if (player == null) {
                    result.error(
                            "Unknown textureId",
                            "No video player associated with texture id " + textureId,
                            null);
                    return;
                }
                onMethodCall(call, result, textureId, player);
                break;
            }
        }
    }

    private void onMethodCall(MethodCall call, Result result, long textureId, IAsunaVideoPlayer player) {
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
                player.sendBufferingUpdate();
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
