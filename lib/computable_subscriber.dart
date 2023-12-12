part of computables;

class ComputableSubscriber<T> extends Computable<T> {
  final List<StreamSubscription> _subscriptions = [];

  ComputableSubscriber({
    T? initialValue,
    bool broadcast = false,
    bool dedupe = false,
  })  : assert(
          initialValue != null || T == Optional<T>,
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
    void Function(S data)? listener, {
    bool disposeOnDone = false,
  }) {
    final initialValue = computable.get();

    if (initialValue is S) {
      listener?.call(initialValue);
    }

    final subscription = computable
        .stream()
        .skip(1)
        .where((value) => value is S)
        .cast<S>()
        .listen((value) {
      listener?.call(value);
    }, onDone: () {
      dispose();
    });
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Subscribes the subscriber [Computable] to the provided source [Stream].
  StreamSubscription<S> subscribeStream<S>(
    Stream<S> stream,
    void Function(S data)? listener, {
    bool disposeOnDone = false,
  }) {
    return subscribe(Computable.fromStream<S?>(stream), (value) {
      listener?.call(value);
    }, disposeOnDone: disposeOnDone);
  }

  /// Subscribes the subscriber [Computable] to the provided source [Future].
  StreamSubscription<S> subscribeFuture<S>(
    Future<S> future,
    void Function(S data)? listener, {
    bool disposeOnDone = false,
  }) {
    return subscribe(Computable.fromFuture<S?>(future), (value) {
      listener?.call(value);
    });
  }

  /// Subscribes the [Computable] to the provided source computable stream and forwards the values it emits
  /// onto the [Computable].
  StreamSubscription<T> forward(
    Computable<T?> computable, {
    bool disposeOnDone = false,
  }) {
    StreamSubscription<T>? subscription;
    subscription = subscribe(computable, add, disposeOnDone: disposeOnDone);
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Subscribes the [Computable] to the provided source [Stream] and forwards the values it emits
  /// onto the [Computable] stream.
  StreamSubscription<T> forwardStream(
    Stream<T> stream, {
    bool disposeOnDone = true,
  }) {
    return subscribeStream(stream, add, disposeOnDone: disposeOnDone);
  }

  StreamSubscription<T> forwardFuture(
    Future<T> future, {
    bool disposeOnDone = true,
  }) {
    return subscribeFuture(future, add, disposeOnDone: disposeOnDone);
  }
}
