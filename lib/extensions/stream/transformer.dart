part of computables;

/// StreamTransformer implementation based on Dart docs:
/// https://api.flutter.dev/flutter/dart-async/StreamTransformer/StreamTransformer.html.
/// Used for transforming an existing input stream to manipulate the data it emits on initially
/// listening to the stream and subsequent data events.
StreamTransformer<S, T> createTransformer<S, T>({
  void Function(StreamController<T> controller)? onListen,
  void Function(StreamController<T> controller, S data)? onData,
}) {
  return StreamTransformer<S, T>(
    (Stream input, bool cancelOnError) {
      // A synchronous stream controller is intended for cases where
      // an already asynchronous event triggers an event on a stream.
      /// Instead of delivering the event to a listener on the next microtask,
      /// it is delivered immediately.
      final controller = StreamController<T>(sync: true);

      controller.onListen = () {
        onListen?.call(controller);
        var subscription = input.listen(
          (data) {
            if (onData != null) {
              onData(controller, data);
            } else {
              controller.add(data);
            }
          },
          onError: controller.addError,
          onDone: controller.close,
          cancelOnError: cancelOnError,
        );
        // Controller forwards pause, resume and cancel events.
        controller
          ..onPause = subscription.pause
          ..onResume = subscription.resume
          ..onCancel = subscription.cancel;
      };

      /// Return a new [StreamSubscription] by listening to the controller's
      /// stream.
      return controller.stream.listen(null);
    },
  );
}
