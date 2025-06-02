part of '../computables.dart';

/// A mixin that enables a [Computable] to forward values from other computables, streams or futures
/// onto itself.
mixin Forwarding<T> on Dependencies<T> {
  @override
  _onDependencyChange(dependency) {
    final value = dependency._value;
    if (value is T) {
      add(value);
    }
  }

  /// Forwards the values of the provided computable onto this computable, immediately
  /// emitting its current value.
  void forward(Computable<T> computable) {
    _addDependency(computable);

    // This computable immediately adds the forwarded computable's current value.
    add(computable.get());
  }

  /// Forwards the values emitted by the stream onto this computable.
  void forwardStream(Stream<T> stream) {
    _addDependency(Computable.fromStream(stream));
  }

  /// Forwards the value of the future onto this computable when it resolves.
  void forwardFuture(Future<T> future) {
    _addDependency(Computable.fromFuture(future));
  }
}

class ForwardingComputable<T> extends Computable<T>
    with Dependencies<T>, Forwarding<T> {
  ForwardingComputable(
    super.initialValue, {
    super.dedupe = true,
  });
}
