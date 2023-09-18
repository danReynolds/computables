part of computables;

class ComputableSubscriber<T> with ComputableMixin<T> implements Computable<T> {
  final List<StreamSubscription> _subscriptions = [];

  ComputableSubscriber({
    T? initialValue,
    bool broadcast = false,
  }) {
    if ((T != Optional<T>) && initialValue == null) {
      throw 'missing [initialValue] for non-nullable type';
    }

    init(initialValue as T, broadcast: broadcast);
  }

  @override
  dispose() {
    super.dispose();

    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
  }

  /// Subscribes the subscriber [Computable] to the provided source [Computable].
  StreamSubscription<S> subscribe<S>(
    Computable<S?> computable, [
    void Function(S data)? listener,
  ]) {
    final subscription = computable
        .stream()
        .where((value) => value is S)
        .cast<S>()
        .listen((value) {
      listener?.call(value);
    });
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Subscribes the subscriber [Computable] to the provided source [Stream].
  StreamSubscription<S> subscribeStream<S>(
    Stream<S> stream, [
    void Function(S data)? listener,
  ]) {
    return subscribe(Computable.fromStream<S?>(stream), (value) {
      listener?.call(value);
    });
  }

  /// Subscribes the subscriber [Computable] to the provided source [Future].
  StreamSubscription<S> subscribeFuture<S>(Future<S> future,
      [void Function(S data)? listener]) {
    return subscribe(Computable.fromFuture<S?>(future), (value) {
      listener?.call(value);
    });
  }

  /// Subscribes the [Computable] to the provided source computable sstream and forwards the values it emits
  /// onto the [Computable].
  StreamSubscription<T> forward(
    Computable<T?> computable, {
    bool disposeOnDone = true,
  }) {
    StreamSubscription<T>? subscription;
    subscription = subscribe(computable, add)
      ..onDone(() {
        subscription!.cancel();

        if (disposeOnDone) {
          dispose();
        }
      });
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Subscribes the [Computable] to the provided source [Stream] and forwards the values it emits
  /// onto the [Computable] stream.
  StreamSubscription<T> forwardStream(
    Stream<T> stream, {
    bool disposeOnDone = true,
  }) {
    return forward(Computable.fromStream<T>(stream, initialValue: get()));
  }

  StreamSubscription<T> forwardFuture(Future<T> future) {
    return forward(Computable.fromFuture<T>(future, initialValue: get()));
  }
}
