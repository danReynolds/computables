part of 'computables.dart';

typedef _Optional<T> = T?;
typedef Dependent = Dependencies;

class Computable<T> {
  StreamController<T>? _controller;
  late StreamFactory<T> _stream;

  bool _isClosed = false;
  bool _isFirstEvent = true;
  bool _eventScheduled = false;

  /// The current set of computables observing this computable.
  final Set<Dependent> _dependents = {};

  late T _value;
  T? _controllerValue;

  /// Whether duplicate values should be discarded and not re-emitted to subscribers.
  final bool dedupe;

  /// The update index counter used to record the global order of updates across all computables.
  static int _nextUpdateIndex = 0;

  int _updateIndex = _nextUpdateIndex++;

  Computable(
    this._value, {
    this.dedupe = true,
  });

  StreamController<T> _initController() {
    final controller = _controller = StreamController<T>.broadcast();
    _stream = StreamFactory(() => controller.stream.startWith(get()));
    return controller;
  }

  /// Private constructor used by [Computation] and [ComputationTransform] to instantiate a [Computable]
  /// without needing to provide an initial value.
  Computable._({
    this.dedupe = true,
  });

  /// Disposes the computable, making it unable to add new values and closing its [StreamController].
  void dispose() {
    _isClosed = true;
    _controller?.close();

    // When this computable is disposed, each of its dependents should remove it as a dependency.
    for (final dependent in _dependents.toList()) {
      dependent._removeDependency(this);
    }
  }

  int get updateIndex {
    return _updateIndex;
  }

  bool get isClosed {
    return _isClosed;
  }

  bool get hasListener {
    return _controller?.hasListener ?? false;
  }

  /// A computable is considered active if it has either client stream listeners or
  /// computable dependents that must be notified of its changes.
  bool get isActive {
    return hasListener || _dependents.isNotEmpty;
  }

  void _addDependent(Dependent dependent) {
    _dependents.add(dependent);
  }

  void _removeDependent(Dependent dependent) {
    _dependents.remove(dependent);
  }

  T add(T updatedValue) {
    assert(!isClosed, 'Cannot add value to a closed computable.');

    _value = updatedValue;
    _updateIndex = _nextUpdateIndex++;

    // Check whether the event should be added to the controller.
    if (isClosed || (!_isFirstEvent && _value == _controllerValue && dedupe)) {
      return _value;
    }

    _controllerValue = _value;
    _isFirstEvent = false;

    if (!_eventScheduled) {
      _eventScheduled = true;
      Future.delayed(
        Duration.zero,
        () {
          if (hasListener) {
            _controller!.add(_value);
          }
          _eventScheduled = false;
        },
      );
    }

    // Notify all dependents that the computable's value has changed.
    for (final dependent in _dependents) {
      dependent._onDependencyChange(this);
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

  /// Returns of a [Stream] of values emitted by the [Computable]. The stream begins with
  /// the current value of the computable.
  Stream<T> stream() {
    if (_controller == null) {
      _initController();
    }
    return _stream;
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
  }) {
    if ((S != _Optional<S>) && initialValue == null) {
      throw 'missing [initialValue] for non-nullable type';
    }

    return ComputableStream<S>(
      stream,
      initialValue: initialValue as S,
    );
  }

  static Computation<T> compute2<T, S1, S2>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    T Function(S1 input1, S2 input2) compute,
  ) {
    return Computation<T>(
      computables: [computable1, computable2],
      compute: (inputs) => compute(inputs[0], inputs[1]),
    );
  }

  static Computation<T> compute3<T, S1, S2, S3>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    T Function(S1 input1, S2 input2, S3 input3) compute,
  ) {
    return Computation<T>(
      computables: [computable1, computable2, computable3],
      compute: (inputs) => compute(inputs[0], inputs[1], inputs[2]),
    );
  }

  static Computation<T> compute4<T, S1, S2, S3, S4>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<S4> computable4,
    T Function(
      S1 input1,
      S2 input2,
      S3 input3,
      S4 input4,
    ) compute,
  ) {
    return Computation<T>(
      computables: [computable1, computable2, computable3, computable4],
      compute: (inputs) => compute(inputs[0], inputs[1], inputs[2], inputs[3]),
    );
  }

  static Computation<T> compute5<T, S1, S2, S3, S4, S5>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<S4> computable4,
    Computable<S5> computable5,
    T Function(
      S1 input1,
      S2 input2,
      S3 input3,
      S4 input4,
      S5 input5,
    ) compute,
  ) {
    return Computation<T>(
      computables: [
        computable1,
        computable2,
        computable3,
        computable4,
        computable5,
      ],
      compute: (inputs) =>
          compute(inputs[0], inputs[1], inputs[2], inputs[3], inputs[4]),
    );
  }

  static Computation<T> compute6<T, S1, S2, S3, S4, S5, S6>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<S4> computable4,
    Computable<S5> computable5,
    Computable<S6> computable6,
    T Function(
      S1 input1,
      S2 input2,
      S3 input3,
      S4 input4,
      S5 input5,
      S6 input6,
    ) compute,
  ) {
    return Computation<T>(
      computables: [
        computable1,
        computable2,
        computable3,
        computable4,
        computable5,
        computable6,
      ],
      compute: (inputs) => compute(
        inputs[0],
        inputs[1],
        inputs[2],
        inputs[3],
        inputs[4],
        inputs[5],
      ),
    );
  }

  static ComputationTransform<T> transform2<T, S1, S2>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<T> Function(S1 input1, S2 input2) transform,
  ) {
    return ComputationTransform<T>(
      computables: [computable1, computable2],
      transform: (inputs) => transform(inputs[0], inputs[1]),
    );
  }

  static ComputationTransform<T> transform3<T, S1, S2, S3>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<T> Function(S1 input1, S2 input2, S3 input3) transform,
  ) {
    return ComputationTransform<T>(
      computables: [computable1, computable2, computable3],
      transform: (inputs) => transform(inputs[0], inputs[1], inputs[2]),
    );
  }

  static ComputationTransform<T> transform4<T, S1, S2, S3, S4>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<S4> computable4,
    Computable<T> Function(
      S1 input1,
      S2 input2,
      S3 input3,
      S4 input4,
    ) transform,
  ) {
    return ComputationTransform<T>(
      computables: [computable1, computable2, computable3, computable4],
      transform: (inputs) =>
          transform(inputs[0], inputs[1], inputs[2], inputs[3]),
    );
  }

  static ComputationTransform<T> transform5<T, S1, S2, S3, S4, S5>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<S4> computable4,
    Computable<S5> computable5,
    Computable<T> Function(
      S1 input1,
      S2 input2,
      S3 input3,
      S4 input4,
      S5 input5,
    ) transform,
  ) {
    return ComputationTransform<T>(
      computables: [
        computable1,
        computable2,
        computable3,
        computable4,
        computable5,
      ],
      transform: (inputs) => transform(
        inputs[0],
        inputs[1],
        inputs[2],
        inputs[3],
        inputs[4],
      ),
    );
  }

  static ComputationTransform<T> transform6<T, S1, S2, S3, S4, S5, S6>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<S4> computable4,
    Computable<S5> computable5,
    Computable<S6> computable6,
    Computable<T> Function(
      S1 input1,
      S2 input2,
      S3 input3,
      S4 input4,
      S5 input5,
      S6 input6,
    ) transform,
  ) {
    return ComputationTransform<T>(
      computables: [
        computable1,
        computable2,
        computable3,
        computable4,
        computable5,
        computable6,
      ],
      transform: (inputs) => transform(
        inputs[0],
        inputs[1],
        inputs[2],
        inputs[3],
        inputs[4],
        inputs[5],
      ),
    );
  }

  static ForwardingComputable<T> forwarder<T>(
    T initialValue, {
    bool dedupe = true,
  }) {
    return ForwardingComputable(
      initialValue,
      dedupe: dedupe,
    );
  }

  Computation<S> map<S>(
    S Function(T value) map, {
    bool? dedupe,
  }) {
    return Computation(
      computables: [this],
      compute: (inputs) => map(inputs.first),
      dedupe: dedupe ?? this.dedupe,
    );
  }

  ComputationTransform<S> transform<S>(
    Computable<S> Function(T value) transform, {
    bool? dedupe,
  }) {
    return ComputationTransform(
      computables: [this],
      transform: (inputs) => transform(inputs.first),
      dedupe: dedupe ?? this.dedupe,
    );
  }
}
