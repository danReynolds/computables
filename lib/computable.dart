part of 'computables.dart';

typedef _Optional<T> = T?;

class Computable<T> {
  StreamController<T>? _controller;
  late StreamFactory<T> _stream;

  bool _isClosed = false;

  final Set<Recomputable> _subscribers = {};

  late T _value;

  /// Whether the [Computable] can have more than one observable subscription. A single-subscription
  /// observable will allow one subscriber and will release its resources automatically when its listener cancels its subscription.
  /// A broadcast observable supports multiple subscribers and must have its resources released manually by calling [dispose].
  final bool broadcast;

  /// Whether duplicate values should be discarded and not re-emitted to subscribers.
  final bool dedupe;

  /// Whether the [Computable] must always be re-evaluated when checking if it is dirty.
  bool deepDirtyCheck;

  Computable(
    this._value, {
    this.broadcast = false,
    this.dedupe = true,
    this.deepDirtyCheck = false,
  });

  StreamController<T> _initController() {
    if (broadcast) {
      _controller = StreamController<T>.broadcast();
    } else {
      _controller = StreamController<T>();
    }

    _stream = StreamFactory(() {
      return _controller!.stream.startWith(get());
    }, broadcast);

    return _controller!;
  }

  /// Private constructor used by [Computation] and [ComputationTransform] to instantiate a [Computable]
  /// without needing to provide an initial value.
  Computable._({
    this.broadcast = false,
    this.dedupe = true,
    this.deepDirtyCheck = false,
  });

  void dispose() {
    _isClosed = true;
    _controller?.close();

    for (final dep in _subscribers) {
      dep._removeDep(this);
    }
  }

  bool get isClosed {
    return _isClosed;
  }

  bool get isDirty {
    return false;
  }

  bool get hasListener {
    return _controller?.hasListener ?? false;
  }

  bool get isActive {
    return hasListener || _subscribers.isNotEmpty;
  }

  void _addSubscriber(Recomputable dep) {
    _subscribers.add(dep);
  }

  void _removeSubscriber(Recomputable dep) {
    _subscribers.remove(dep);
  }

  T add(T updatedValue) {
    assert(!isClosed, 'Cannot add value to a closed computable.');

    if (isClosed || (get() == updatedValue && dedupe)) {
      return get();
    }

    _value = updatedValue;

    for (final subscriber in _subscribers) {
      subscriber._dirty(true);
    }

    final controller = _controller;
    if (hasListener) {
      controller!.add(_value);
    }

    return get();
  }

  T update(T Function(T value) updateFn) {
    return add(updateFn(get()));
  }

  /// Returns the value of the computable.
  T get() {
    return _value;
  }

  /// Returns of a [Stream] of values emitted by the [Computable]. The stream begins with
  /// the current value of the computable.
  Stream<T> stream() {
    if (_controller == null) {
      _initController();
    }
    return _stream;
  }

  Map inspect() {
    return {
      "value": get(),
      "subscribers": _subscribers,
    };
  }

  static Computable<S> fromFuture<S>(
    Future<S> future, {
    S? initialValue,
  }) {
    if ((S != _Optional<S>) && initialValue == null) {
      throw 'missing [initialValue] for non-nullable type.';
    }

    return ComputableFuture<S>(
      future,
      initialValue: initialValue as S,
    );
  }

  static Computable<S> fromStream<S>(
    Stream<S> stream, {
    S? initialValue,
    bool broadcast = false,
  }) {
    if ((S != _Optional<S>) && initialValue == null) {
      throw 'missing [initialValue] for non-nullable type';
    }

    return ComputableStream<S>(
      stream,
      initialValue: initialValue as S,
    );
  }

  static ComputableSubscriber<S> subscriber<S>(
    S initialValue, {
    bool broadcast = false,
  }) {
    return ComputableSubscriber(
      initialValue: initialValue,
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

  static Computable<T> compute4<T, S1, S2, S3, S4>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<S4> computable4,
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
}
