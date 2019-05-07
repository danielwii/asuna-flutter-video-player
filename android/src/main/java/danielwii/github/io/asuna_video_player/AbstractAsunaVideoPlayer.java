package danielwii.github.io.asuna_video_player;

import android.net.Uri;

abstract class AbstractAsunaVideoPlayer implements IAsunaVideoPlayer {

    boolean isFileOrAsset(Uri uri) {
        if (uri == null || uri.getScheme() == null) {
            return false;
        }
        String scheme = uri.getScheme();
        return scheme.equals("file") || scheme.equals("asset");
    }

}
