part of computables;

/// A mixin that implements the recomputable behavior used by a [Computation] and [ComputationTransform].
mixin Recomputable<T> on Computable<T> {
  /// A mutable dirty flag on the computable is used as an optimization so that its dependency
  /// tree does not need to be checked if the computable has been directly marked as dirty.
  bool _isDirty = false;

  final Set<Computable> _dependencies = {};

  @override
  get isDirty {
    return _isDirty || _dependencies.any((dep) => dep.isDirty);
  }

  void _dirty() {
    if (!_isDirty) {
      _isDirty = true;

      // When a computable's dependencies are updated and the computable is marked as dirty,
      // it schedules an async task to perform its recomputation. Performing the recomputation
      // asynchronously has a few benefits:
      //
      // 1. It batches together synchronous updates to multiple dependencies into a single recomputation.
      // 2. It frees up the main isolate to process other pending events before having to perform what could
      //    be a heavy recomputation.
      Future.delayed(Duration.zero, () {
        // When the dirty computable's asynchronous recomputation is later run, it may no longer be necessary
        // to recompute, since if the dirty computable's value had been accessed synchronously before it could
        // process its async recomputation, it would've updated synchronously and marked itself as no longer dirty.
        if (isDirty) {
          _isDirty = false;
          add(_recompute());
        }
      });
    }
  }

  @override
  get() {
    // Since recomputations of dirty computables are performed asynchronously, if the value of a dirty
    // computable is accessed before it has been recomputed, then it must be recomputed synchronously.
    if (isDirty) {
      _isDirty = false;
      return add(_recompute());
    }

    return _value;
  }

  T _recompute();
}
