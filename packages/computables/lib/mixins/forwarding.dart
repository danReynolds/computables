part of '../computables.dart';

/// A mixin that enables a [Computable] to forward values from other computables, streams or futures
/// onto itself.
mixin Forwarding<T> on Dependencies<T> {
  /// Forwards the values of the provided computable onto this computable, immediately
  /// emitting its current value.
  void forward(Computable<T> computable) {
    add(computable.get());

    _addDependency(computable);
  }

  /// Forwards the values emitted by the stream onto this computable.
  void forwardStream(Stream<T> stream) {
    _addDependency(Computable.fromStream(stream, initialValue: get()));
  }

  /// Forwards the value of the future onto this computable when it resolves.
  void forwardFuture(Future<T> future) {
    _addDependency(Computable.fromFuture(future, initialValue: get()));
  }

  /// A forwarding computable returns the most recently updated value added to it directly
  /// or from one of its dependencies.
  @override
  get() {
    if (_dependencies.isEmpty) {
      return super.get();
    }

    final latestUpdate = (_dependencies.toList()
          ..sort((a, b) => b.updateIndex.compareTo(a.updateIndex)))
        .first;

    if (latestUpdate.updateIndex > updateIndex) {
      _updateIndex = latestUpdate.updateIndex;
      _value = latestUpdate.get();
    }

    return super.get();
  }
}

class ForwardingComputable<T> extends Computable<T>
    with Dependencies<T>, Forwarding<T> {
  ForwardingComputable(
    super.initialValue, {
    super.dedupe = true,
  });
}
