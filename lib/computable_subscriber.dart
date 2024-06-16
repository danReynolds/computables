part of computables;

class ComputableSubscriber<T> extends Computable<T> {
  final List<StreamSubscription> _subscriptions = [];

  ComputableSubscriber({
    T? initialValue,
    bool broadcast = false,
    bool dedupe = true,
  })  : assert(
          initialValue != null || T == _Optional<T>,
          'ComputableSubscriber must specify a nullable type or an initial value.',
        ),
        super(
          initialValue as T,
          broadcast: broadcast,
          dedupe: dedupe,
        );

  @override
  dispose() {
    super.dispose();

    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
  }

  /// Subscribes the subscriber [Computable] to the provided source [Computable].
  StreamSubscription<S> subscribe<S>(
    Computable<S?> computable,
    void Function(S data)? listener,
  ) {
    final initialValue = computable.get();

    if (initialValue is S) {
      listener?.call(initialValue);
    }

    final subscription = computable
        .stream()
        .where((value) => value is S)
        .cast<S>()
        .listen(listener);
    _subscriptions.add(subscription);

    return subscription;
  }

  // /// Subscribes the subscriber [Computable] to the provided source [Stream].
  StreamSubscription<S> subscribeStream<S>(
    Stream<S> stream,
    void Function(S data)? listener,
  ) {
    return subscribe(Computable.fromStream<S?>(stream), listener);
  }

  /// Subscribes the subscriber [Computable] to the provided source [Future].
  StreamSubscription<S> subscribeFuture<S>(
    Future<S> future,
    void Function(S data)? listener,
  ) {
    return subscribe(Computable.fromFuture<S?>(future), listener);
  }

  /// Subscribes the [Computable] to the provided source computable stream and forwards the values it emits
  /// onto the [Computable].
  StreamSubscription<T> forward(Computable<T> computable) {
    return subscribe(computable, add);
  }

  /// Subscribes the [Computable] to the provided [Stream] and forwards the values it emits
  /// onto the [Computable] stream.
  StreamSubscription<T> forwardStream(Stream<T> stream) {
    return subscribeStream(stream, add);
  }

  /// Subscribes the [Computable] to the provided [Future] and forwards its resolved value
  /// onto the [Computable] stream.
  StreamSubscription<T> forwardFuture(Future<T> future) {
    return subscribeFuture(future, add);
  }
}
