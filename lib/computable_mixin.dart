part of 'computables.dart';

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

/// A class that provides an observable interface for the access and streaming of stored values.
mixin ComputableMixin<T> {
  late final StreamController<ComputableChangeRecord<T>> _controller;
  late StreamFactory<T> _valueStream;
  late StreamFactory<ComputableChangeRecord<T>> _changeStream;
  bool _hasEmitted = false;

  late T _value;
  late T _prevValue;
  late final bool broadcast;

  void init(
    T initialValue, {
    /// Whether the [Computable] can have more than one observable subscription. A single-subscription
    /// observable will allow one listener and release its resources automatically when its listener cancels its subscription.
    /// A broadcast observable must have its resources released manually by calling [dispose].
    /// The term *broadcast* is used to refer to a a multi-subscription observable since it is common observable terminology and
    /// the term broadcast is to mean something different in the library compared to its usage in the underlying Dart [Stream] implementation.
    required bool broadcast,
  }) {
    this.broadcast = broadcast;

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
}
