package danielwii.github.io.asuna_video_player;

import android.util.Log;

import java.util.ArrayList;
import java.util.List;

import io.flutter.plugin.common.EventChannel;

final class QueuingEventSink implements EventChannel.EventSink {

    private static final String TAG = QueuingEventSink.class.getSimpleName();

    private static class EndOfStreamEvent {}

    private static class ErrorEvent {
        String code;
        String message;
        Object details;

        public ErrorEvent(String code, String message, Object details) {
            this.code = code;
            this.message = message;
            this.details = details;
        }
    }

    private EventChannel.EventSink delegate;
    private List<Object>           eventQueue = new ArrayList<>();
    private boolean                done       = false;

    public void setDelegate(EventChannel.EventSink delegate) {
        this.delegate = delegate;
        maybeFlush();
    }

    private void enqueue(Object event) {
        if (done) {
            return;
        }
        eventQueue.add(event);
    }

    private void maybeFlush() {
        if (delegate == null) {
            return;
        }
        for (Object event : eventQueue) {
            if (event instanceof EndOfStreamEvent) {
                delegate.endOfStream();
            } else if (event instanceof ErrorEvent) {
                ErrorEvent errorEvent = (ErrorEvent) event;
                delegate.error(errorEvent.code, errorEvent.message, errorEvent.details);
            } else {
                delegate.success(event);
            }
        }
        eventQueue.clear();
    }

    @Override
    public void success(Object event) {
        Log.d(TAG, event.toString());
        enqueue(event);
        maybeFlush();
    }

    @Override
    public void error(String errorCode, String errorMessage, Object errorDetails) {
        enqueue(new ErrorEvent(errorCode, errorMessage, errorDetails));
        maybeFlush();
    }

    @Override
    public void endOfStream() {
        enqueue(new EndOfStreamEvent());
        maybeFlush();
        done = true;
    }
}
