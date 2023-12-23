part of computables;

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
}
