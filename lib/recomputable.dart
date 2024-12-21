part of computables;

/// A mixin that implements the recomputable behavior used by a [Computation] and [ComputationTransform].
///
/// A recomputable can be either *active* or *inactive*.
///
/// Active:
/// An active recomputable has subscribers, either client subscribers through the [stream] API, or
/// internal computable subscribers that depend on it. On update, an active computable immediately pushes down
/// its dirty state to its subscribers and schedules itself for recomputation.
///
/// Inactive:
/// An inactive recomputable will mark itself as dirty but has no subscribers to notify and will therefore
/// not schedule itself for recomputation.
mixin Recomputable<T> on Computable<T> {
  /// A mutable dirty flag on the computable is used as an optimization so that its dependency
  /// tree does not need to be checked if the computable has been directly marked as dirty.
  bool _isDirty = false;

  /// Whether the recomputable is scheduled for recomputation.
  bool _isScheduled = false;

  final Map<Computable, dynamic> _depsCache = {};

  T? _pendingValue;

  /// The subset of dependencies of the recomputable that require a dirty check.
  final Set<Computable> _deepDirtyCheckDeps = {};

  void init(List<Computable> deps) {
    for (final dep in deps) {
      _addDep(dep);
    }
  }

  @override
  _initController() {
    final controller = super._initController();

    controller.onListen = () {
      if (_subscribers.isEmpty) {
        for (final dep in _depsCache.keys) {
          dep._addSubscriber(this);
        }
      }
    };
    controller.onCancel = () {
      for (final dep in _depsCache.keys) {
        dep._removeSubscriber(this);
      }
    };

    return controller;
  }

  void _addDep(Computable dep) {
    _isDirty = true;

    _depsCache[dep] = null;

    if (isActive) {
      dep._addSubscriber(this);
    }

    if (dep.deepDirtyCheck) {
      _deepDirtyCheckDeps.add(dep);
    }
  }

  void _removeDep(Computable dep) {
    _isDirty = true;

    _depsCache.remove(dep);
    _deepDirtyCheckDeps.remove(dep);

    if (isActive) {
      dep._removeSubscriber(this);
    }

    // If the recomputable has no remaining dependencies then it can be disposed as well.
    if (_depsCache.isEmpty) {
      dispose();
    }
  }

  @override
  _addSubscriber(dep) {
    if (!isActive) {
      for (final dep in _depsCache.keys) {
        dep._addSubscriber(this);
      }
    }

    super._addSubscriber(dep);
  }

  @override
  _removeSubscriber(dep) {
    super._removeSubscriber(dep);

    if (isActive) {
      for (final dep in _depsCache.keys) {
        dep._removeSubscriber(this);
      }
    }
  }

  @override
  get isDirty {
    return _isDirty ||
        (isActive && _deepDirtyCheckDeps.any((dep) => dep.isDirty)) ||
        _depsCache.keys.any((dep) => dep.get() != _depsCache[dep]);
  }

  void _dirty(
    /// Whether the dirtied recomputable should be scheduled for async recomputation
    /// when it is marked as dirty.
    bool schedule,
  ) {
    if (schedule && !_isScheduled && isActive) {
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
          add(_cachedRecompute());
        } else {
          add(_pendingValue ?? _cachedRecompute());
        }
        _pendingValue = null;
        _isScheduled = false;
      });
    }

    if (!_isDirty) {
      _isDirty = true;

      for (final subscriber in _subscribers) {
        // Subscribers are notified immediately, however, scheduling each subscriber is deferred until after
        // this computable has recomputed and is done as part of the subsequent [add] call by this computable.
        // This is done to break up recomputations of subscribers into different tasks of the event loop, giving space
        // for other operations to be run on the main isolate in between recomputations.
        subscriber._dirty(false);
      }
    }
  }

  @override
  get() {
    // Since recomputations of dirty computables are scheduled asynchronously, if the value of a dirty
    // computable is accessed before it has been recomputed, then it must be recomputed immediately.
    if (isDirty) {
      _isDirty = false;

      if (_isScheduled) {
        // The recomputed value is cached so that it does not need to be recomputed if it has not been re-marked
        // as dirty when it asynchronously runs its recomputation.
        _pendingValue = _cachedRecompute();
      } else {
        _value = _cachedRecompute();
      }
    }

    return _pendingValue ?? _value;
  }

  @override
  Map inspect() {
    return {
      ...super.inspect(),
      "dependencies": _depsCache,
    };
  }

  T _recompute();

  T _cachedRecompute() {
    for (final dep in _depsCache.keys) {
      _depsCache[dep] = dep.get();
    }

    return _recompute();
  }
}
