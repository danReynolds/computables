part of 'computables.dart';

typedef Optional<T> = T?;

typedef ComputableChangeRecord<T> = (T prev, T next);

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

class Computable<T> {
  late final StreamController<ComputableChangeRecord<T>> _controller;
  late StreamFactory<T> _valueStream;
  late StreamFactory<ComputableChangeRecord<T>> _changeStream;
  bool _hasEmitted = false;

  late T _value;
  late T _prevValue;
  late final bool broadcast;

  Computable(
    T initialValue, {
    /// Whether the [Computable] can have more than one observable subscription. A single-subscription
    /// observable will allow one listener and release its resources automatically when its listener cancels its subscription.
    /// A broadcast observable must have its resources released manually by calling [dispose].
    /// The term *broadcast* is used to refer to a a multi-subscription observable since it is common observable terminology and
    /// the term broadcast is to mean something different in the library compared to its usage in the underlying Dart [Stream] implementation.
    this.broadcast = false,
  }) {
    if (broadcast) {
      _controller = StreamController<ComputableChangeRecord<T>>.broadcast();
    } else {
      _controller =
          StreamController<ComputableChangeRecord<T>>(onCancel: dispose);
    }

    _valueStream = StreamFactory(_valueStreamFactory);
    _changeStream = StreamFactory(_changeStreamFactory);

    _prevValue = _value = initialValue;

    /// Emit the initial value immediately on the controller if either it is non-null
    /// or the type of the [Computable] is optional.
    if (_value != null || T == Optional<T>) {
      add(initialValue);
    }
  }

  static Computable<S> fromValue<S>(
    S initialValue, {
    bool broadcast = false,
  }) {
    return Computable<S>(initialValue, broadcast: broadcast);
  }

  static Computable<S> fromIterable<S>(
    Iterable<S> iterable, {
    bool broadcast = false,
  }) {
    if ((S != Optional<S>) && iterable.isEmpty) {
      throw 'missing iterable value for non-nullable type.';
    }

    final computable = Computable(iterable.first, broadcast: broadcast);
    for (final value in iterable.skip(1)) {
      computable.add(value);
    }

    return computable;
  }

  static Computable<S> fromFuture<S>(
    Future<S> future, {
    S? initialValue,
    bool broadcast = false,
  }) {
    if ((S != Optional<S>) && initialValue == null) {
      throw 'missing [initialValue] for non-nullable type.';
    }

    return ComputableFuture<S>(
      future,
      initialValue: initialValue as S,
      broadcast: broadcast,
    );
  }

  static Computable<S> fromStream<S>(
    Stream<S> stream, {
    S? initialValue,
    bool broadcast = false,
  }) {
    if ((S != Optional<S>) && initialValue == null) {
      throw 'missing [initialValue] for non-nullable type';
    }

    return ComputableStream<S>(
      stream,
      initialValue: initialValue as S,
      broadcast: broadcast,
    );
  }

  static Computable<T> compute1<T, S1>(
    Computable<S1> computable1,
    T Function(S1 input1) compute, {
    bool broadcast = false,
  }) {
    return Computation<T>(
      computables: [computable1],
      compute: (inputs) => compute(inputs[0]),
      broadcast: broadcast,
    );
  }

  static Computable<T> compute2<T, S1, S2>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    T Function(S1 input1, S2 input2) compute, {
    bool broadcast = false,
  }) {
    return Computation<T>(
      computables: [computable1, computable2],
      compute: (inputs) => compute(inputs[0], inputs[1]),
      broadcast: broadcast,
    );
  }

  static Computable<T> compute3<T, S1, S2, S3>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    T Function(S1 input1, S2 input2, S3 input3) compute, {
    bool broadcast = false,
  }) {
    return Computation<T>(
      computables: [computable1, computable2, computable3],
      compute: (inputs) => compute(inputs[0], inputs[1], inputs[2]),
      broadcast: broadcast,
    );
  }

  static Computation<T> compute4<T, S1, S2, S3, S4>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<S3> computable4,
    T Function(
      S1 input1,
      S2 input2,
      S3 input3,
      S4 input4,
    ) compute, {
    bool broadcast = false,
  }) {
    return Computation<T>(
      computables: [computable1, computable2, computable3, computable4],
      compute: (inputs) => compute(inputs[0], inputs[1], inputs[2], inputs[3]),
      broadcast: broadcast,
    );
  }

  static Computable<T> transform1<T, S1>(
    Computable<S1> computable1,
    Computable<T> Function(S1 input1) transform, {
    bool broadcast = false,
  }) {
    return ComputationTransform<T>(
      computables: [computable1],
      transform: (inputs) => transform(inputs[0]),
      broadcast: broadcast,
    );
  }

  static Computable<T> transform2<T, S1, S2>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<T> Function(S1 input1, S2 input2) transform, {
    bool broadcast = false,
  }) {
    return ComputationTransform<T>(
      computables: [computable1, computable2],
      transform: (inputs) => transform(inputs[0], inputs[1]),
      broadcast: broadcast,
    );
  }

  static Computable<T> transform3<T, S1, S2, S3>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<T> Function(S1 input1, S2 input2, S3 input3) transform, {
    bool broadcast = false,
  }) {
    return ComputationTransform<T>(
      computables: [computable1, computable2, computable3],
      transform: (inputs) => transform(inputs[0], inputs[1], inputs[2]),
      broadcast: broadcast,
    );
  }

  static Computable<T> transform4<T, S1, S2, S3, S4>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<S4> computable4,
    Computable<T> Function(
      S1 input1,
      S2 input2,
      S3 input3,
      S4 input4,
    ) transform, {
    bool broadcast = false,
  }) {
    return ComputationTransform<T>(
      computables: [computable1, computable2, computable3, computable4],
      transform: (inputs) =>
          transform(inputs[0], inputs[1], inputs[2], inputs[3]),
      broadcast: broadcast,
    );
  }

  static ComputableSubscriber<T> subscriber<T>({
    T? initialValue,
    bool broadcast = false,
  }) {
    return ComputableSubscriber<T>(
      initialValue: initialValue,
      broadcast: broadcast,
    );
  }

  Stream<T> _valueStreamFactory() {
    final stream = _controller.stream.map((record) {
      final (_, value) = record;
      return value;
    });

    // Broadcast stream controllers do not buffer events emitted when there are no listeners,
    // so when a listener subscribes to the controller's stream, we provide it with the current value.
    if (_hasEmitted && broadcast) {
      return stream.startWith(_value);
    }
    return stream;
  }

  Stream<ComputableChangeRecord<T>> _changeStreamFactory() {
    final stream = _controller.stream.where((record) {
      final (prevValue, value) = record;
      return prevValue != value;
    });

    // Broadcast stream controllers do not buffer events emitted when there are no listeners,
    // so when a listener subscribes to the controller's stream, we provide it with the current value.
    if (_hasEmitted && broadcast && _prevValue != _value) {
      return stream.startWith((_prevValue, _value));
    }
    return stream;
  }

  void dispose() {
    _controller.close();
  }

  bool get isClosed {
    return _controller.isClosed;
  }

  T add(T updatedValue) {
    if (_controller.isClosed) {
      return _value;
    }

    if (!_hasEmitted) {
      _hasEmitted = true;
    }

    _prevValue = _value;
    _value = updatedValue;

    _controller.add((_prevValue, _value));
    return _value;
  }

  T get() {
    return _value;
  }

  Stream<T> stream() {
    return _valueStream;
  }

  Stream<ComputableChangeRecord<T>> streamChanges() {
    return _changeStream;
  }

  Computable<S> map<S>(S Function(T value) map) {
    return Computable.compute1(this, map);
  }

  Computable<S> transform<S>(Computable<S> Function(T value) transform) {
    return Computable.transform1(this, transform);
  }
}
