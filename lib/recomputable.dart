part of computables;

/// A mixin that implements the recomputable behavior used by a [Computation] and [ComputationTransform].
mixin Recomputable<T> on Computable<T> {
  /// A mutable dirty flag on the computable is used as an optimization so that its dependency
  /// tree does not need to be checked if the computable has been directly marked as dirty.
  bool _isDirty = false;

  /// Whether the recomputable is scheduled for recomputation.
  bool _isScheduled = false;

  final Set<Computable> _dependencies = {};

  /// Whether the recomputable should re-compute itself lazily when its value is accessed either via [get] or an active
  /// [stream] listener.
  late final bool _isLazy;

  T? _pendingValue;

  /// The subset of dependencies of the recomputable that require a dirty check.
  final Set<Computable> _dirtyCheckDeps = {};

  void init(
    List<Computable> deps, {
    bool lazy = false,
  }) {
    _isLazy = lazy;

    for (final dep in deps) {
      _addDep(dep);
    }

    if (lazy) {
      _isDirty = true;
    } else {
      _value = _recompute();
    }
  }

  void _addDep(Computable dep) {
    _dependencies.add(dep);
    if (dep.deepDirtyCheck) {
      _dirtyCheckDeps.add(dep);
    }
    dep._dependents.add(this);
  }

  void _removeDep(Computable dep) {
    _dependencies.remove(dep);
    _dirtyCheckDeps.remove(dep);

    if (!dep.isClosed) {
      dep._dependents.remove(this);
    }

    // If the recomputable is no longer dependent on any non-disposed computables, then
    // if it is non-broadcast computable, it can be disposed as well. If it *is* broadcast computable,
    // then it should remain open since new subscribers could request its value.
    if (_dependencies.isEmpty && !broadcast) {
      dispose();
    }
  }

  @override
  get isDirty {
    return _isDirty || _dirtyCheckDeps.any((dep) => dep.isDirty);
  }

  @override
  get isLazy {
    return _isLazy;
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

    // A dirty recomputable is scheduled for recomputation asynchronously. This has a couple advantages:
    //
    // 1. It batches together synchronous updates to multiple dependencies into a single recomputation.
    // 2. It frees up the main isolate to process other pending events before having to perform what could
    //    be a heavy recomputation.
    if (schedule && !_isScheduled && (!isLazy || hasListener)) {
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

  @override
  Map inspect() {
    return {
      ...super.inspect(),
      "dependencies": _dependencies,
    };
  }

  T _recompute();
}
