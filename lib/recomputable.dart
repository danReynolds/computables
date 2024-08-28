part of computables;

/// A mixin that implements the recomputable behavior used by a [Computation] and [ComputationTransform].
mixin Recomputable<T> on Computable<T> {
  /// A mutable dirty flag on the computable is used as an optimization so that its dependency
  /// tree does not need to be checked if the computable has been directly marked as dirty.
  bool _isDirty = false;

  /// Whether the recomputable is scheduled for recomputation.
  bool _isScheduled = false;

  T? _pendingValue;

  final Set<Computable> _deps = {};
  final Set<Computable> _deepDeps = {};

  void init(List<Computable> deps) {
    for (final dep in deps) {
      _addDep(dep);
    }
    _value = _recompute();
  }

  void _addDep(Computable dep) {
    _deps.add(dep);
    if (dep.deepDirtyCheck) {
      _deepDeps.add(dep);
    }
    dep._dependents.add(this);
  }

  void _removeDep(Computable dep) {
    _deps.remove(dep);
    _deepDeps.remove(dep);
    dep._dependents.remove(this);
  }

  @override
  get deepDirtyCheck {
    return _deepDeps.isNotEmpty;
  }

  @override
  get isDirty {
    return _isDirty || deepDirtyCheck && _deepDeps.any((dep) => dep.isDirty);
  }

  void _dirty(
    /// Whether the dirtied recomputable should be scheduled for async recomputation
    /// when it is marked as dirty.
    bool schedule,
  ) {
    if (!_isDirty) {
      _isDirty = true;

      for (final dep in _dependents) {
        // Dependencies are marked as dirty immediately, however they are not scheduled
        // yet, this is deferred until after the current computable's recomputation is completed.
        dep._dirty(false);
      }
    }

    if (schedule) {
      // A dirty recomputable is scheduled for recomputation asynchronously. This has a couple advantages:
      //
      // 1. It batches together synchronous updates to multiple dependencies into a single recomputation.
      // 2. It frees up the main thread to process other pending events before having to perform what could
      //    be a heavy recomputation.
      if (!_isScheduled) {
        _isScheduled = true;
        Future.delayed(Duration.zero, () {
          // The computable may have recomputed in between scheduling and executing its async recomputation,
          // in which case if it has not been re-dirtied, the cached pending value can be used instead of recomputing.
          if (isDirty) {
            add(_recompute());
            _isDirty = false;
          } else {
            add(_pendingValue ?? _recompute());
          }
          _pendingValue = null;
          _isScheduled = false;
        });
      }
    }
  }

  @override
  get() {
    // Since recomputations of dirty computables are performed asynchronously, if the value of a dirty
    // computable is accessed before it has been recomputed, then it must be recomputed synchronously.
    if (isDirty) {
      _isDirty = false;
      // The recomputed value is cached so that it does not need to be recomputed if it has not been re-marked
      // as dirty when it asynchronously runs its recomputation.
      return _pendingValue = _recompute();
    }

    return _pendingValue ?? _value;
  }

  T _recompute();
}
