part of 'computables.dart';

typedef _Optional<T> = T?;

class Computable<T> {
  /// The synchronous stream controller is used for delivering updates to *internal*
  /// subscribers like [Computation] and [ComputationTransform] so that they receive
  /// updates immediately and always return the latest value through their [get] API.
  /// Example:
  /// ```dart
  /// final computable1 = Computable(1);
  /// final computable2 = Computable(2);

  /// final computation = Computable.compute2(
  ///   computable1,
  ///   computable2,
  ///   (input1, input2) => input1 + input2,
  /// );
  /// print(computation.get(), 3);
  /// computable1.add(2);
  /// print(computation.get(), 4);
  /// ```
  ///
  /// If the asynchronous stream controller was used for both external and internal subscribers, then
  /// the update to `computable1` wouldn't update the `computation` within the current task of the event loop, and
  /// accessing the computation's latest value through the `get` API would be stale. Instead, we use a sync stream controller
  /// so that internal subscribers like the computation immediately reflect the update.
  late final StreamController<T> _syncController;

  /// The asynchronous stream controller is used for delivering updates to *external*
  /// subscribers accessing the computable from the [stream] API.
  late final StreamController<T> _asyncController;

  late StreamFactory<T> _valueStream;

  bool _isClosed = false;
  bool _isInitialized = false;

  late T _value;

  /// Whether the [Computable] can have more than one observable subscription. A single-subscription
  /// observable will allow one subscriber and will release its resources automatically when its listener cancels its subscription.
  /// A broadcast observable supports multiple subscribers and must have its resources released manually by calling [dispose].
  final bool broadcast;

  /// Whether duplicate values should be discarded and not re-emitted to subscribers.
  final bool dedupe;

  Computable(
    T initialValue, {
    this.broadcast = false,
    this.dedupe = true,
  }) {
    _init(initialValue);
  }

  void _init(T initialValue) {
    if (broadcast) {
      _syncController = StreamController<T>.broadcast(sync: true);
      _asyncController = StreamController<T>.broadcast();
    } else {
      _syncController = StreamController<T>(sync: true, onCancel: dispose);
      _asyncController = StreamController<T>(onCancel: dispose);
    }

    _valueStream = StreamFactory(() {
      return _asyncController.stream.startWith(_value);
    });

    _isInitialized = true;
    _value = initialValue;
  }

  /// Private constructor used by [Computation] and [ComputationTransform] to instantiate a [Computable]
  /// without needing to provide an initial value.
  Computable._({
    this.broadcast = false,
    this.dedupe = true,
  });

  void dispose() {
    _isClosed = true;
    _asyncController.close();
    _syncController.close();
  }

  bool get isClosed {
    return _isClosed;
  }

  T add(T updatedValue) {
    if (!_isInitialized) {
      _init(updatedValue);
      return _value;
    }

    if (isClosed || _value == updatedValue && dedupe) {
      return _value;
    }

    _value = updatedValue;

    if (_syncController.hasListener) {
      _syncController.add(_value);
    }
    if (_asyncController.hasListener) {
      _asyncController.add(_value);
    }

    return _value;
  }

  T update(T Function(T value) updateFn) {
    return add(updateFn(get()));
  }

  /// Returns the value of the computable.
  T get() {
    return _value;
  }

  /// Private synchronous stream API used by [Computation] and [ComputationTransform] to immediately
  /// recompute updates from dependencies.
  Stream<T> _syncStream() {
    return _syncController.stream;
  }

  /// Returns of a [Stream] of values emitted by the [Computable]. The stream begins with
  /// the current value of the computable.
  Stream<T> stream() {
    return _valueStream;
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
