part of computables;

/// A mixin that implements the recomputable behavior used by a [Computation] and [ComputationTransform].
mixin Recomputable<T> on Computable<T> {
  /// A mutable dirty flag on the computable is used as an optimization so that its dependency
  /// tree does not need to be checked if the computable has been directly marked as dirty.
  bool _isDirty = false;

  /// Whether the recomputable is scheduled for recomputation.
  bool _isScheduled = false;

  final Set<Computable> _dependencies = {};

  /// Whether the recomputable should automatically recompute its value when it is marked as dirty or
  /// lazily only recompute when its value is pulled by [get] or [stream].
  late final bool _isLazy;

  T? _pendingValue;

  /// The subset of dependencies of the recomputable that require a dirty check.
  final Set<Computable> _dirtyCheckDeps = {};

  void init(
    List<Computable> deps, {
    bool lazy = true,
  }) {
    if (lazy) {
      _isDirty = true;
    } else {
      _value = _recompute();
    }

    _isLazy = lazy;
    _hasValue = !isLazy;

    for (final dep in deps) {
      _addDep(dep);
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

    // If the recomputable is no longer dependent on any non-disposed computables then it
    // can be disposed as well.
    if (_dependencies.isEmpty) {
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
    if (schedule && !_isScheduled && (!isLazy || hasListener)) {
      _isScheduled = true;

      // A dirty recomputable is scheduled for recomputation asynchronously. This has a couple advantages:
      //
      // 1. It batches together synchronous updates to multiple dependencies into a single recomputation.
      // 2. It frees up the main isolate to process other pending events before having to perform what could
      //    be a heavy recomputation.
      Future.delayed(Duration.zero, () {
        // The computable may have recomputed in between scheduling and executing its async recomputation,
        // in which case if it has not been re-dirtied, the cached pending value can be used instead of recomputing.
        if (isDirty) {
          _isDirty = false;
          add(_recompute());
        } else {
          add(_pendingValue ?? _recompute());
        }
        _pendingValue = null;
        _isScheduled = false;
      });
    }

    if (!_isDirty) {
      _isDirty = true;

      for (final dep in _dependents) {
        // Dependencies are marked as dirty immediately, however, if this computable is scheduled for recomputation,
        // then scheduling each dependency is deferred until after this computable has recomputed and is done as part
        // of the subsequent [add] call by this computable. This is done to break up recomputations of dependencies
        // into different tasks of the event loop, giving space for other operations to be run on the main isolate in
        // between recomputations.
        dep._dirty(!_isScheduled);
      }
    }
  }

  @override
  get() {
    // Since recomputations of dirty computables are scheduled asynchronously, if the value of a dirty
    // computable is accessed before it has been recomputed, then it must be recomputed immediately.
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
