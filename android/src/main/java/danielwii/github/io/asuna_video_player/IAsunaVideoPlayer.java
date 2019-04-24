package danielwii.github.io.asuna_video_player;

public interface IAsunaVideoPlayer {
    void play();

    void pause();

    void setLooping(boolean looping);

    void setVolume(double value);

    void seekTo(int location);

    long getPosition();

    void dispose();
}
