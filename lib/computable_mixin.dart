part of 'computables.dart';

typedef ComputableChangeRecord<T> = (T prev, T next);

/// A class that provides an observable interface for the access and streaming of stored values.
mixin ComputableMixin<T> {
  late final StreamController<ComputableChangeRecord<T>> _controller;
  late final Stream<T> _valueStream;
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
    if (broadcast) {
      _controller = StreamController<ComputableChangeRecord<T>>.broadcast();
    } else {
      _controller =
          StreamController<ComputableChangeRecord<T>>(onCancel: dispose);
    }

    _valueStream = _controller.stream.map((record) {
      final (_, next) = record;
      return next;
    });

    _prevValue = _value = initialValue;
    _controller.add((_prevValue, _value));
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
    return _controller.stream;
  }
}
