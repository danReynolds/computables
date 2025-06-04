part of '../../computables.dart';

/// Returns a new stream produced by calling [factory] whenever a listener subscribes to the [StreamFactory].
class StreamFactory<T> extends Stream<T> {
  final Stream<T> Function() factory;

  StreamFactory(this.factory);

  @override
  StreamSubscription<T> listen(
    void Function(T value)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return factory().listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  /// A stream factory overrides the broadcast property of a [Stream] to indicate that it can have multiple listeners,
  /// since it produces a new stream each time a listener subscribes.
  @override
  get isBroadcast {
    return true;
  }
}
