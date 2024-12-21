part of computables;

/// A mixin that implements the recomputable behavior used by a [Computation] and [ComputationTransform].
///
/// A recomputable can be either *active* or *inactive*.
///
/// Active:
/// An active recomputable is one that either has client stream listeners or dependent computables watching it.
/// Active computables **push** updates automatically and schedule a recomputation when they become dirty.
///
/// Inactive:
/// An inactive recomputable does not recompute automatically. Instead, it lazily recomputes its value when it is accessed.
///
/// All computables are inactive by default until a stream listener or watcher is added.
mixin Recomputable<T> on Computable<T> {
  /// The dependencies of this computable.
  final Set<Computable> _deps = {};

  /// A cache of the values of the dependencies of this computable from this computable's most recent recomputation.
  final Map<Computable, dynamic> _depsCache = {};

  /// Whether this computation is scheduled to perform an asynchronous recomputation.
  bool _isScheduled = false;

  void _initDeps(List<Computable> dependencies) {
    for (final dependency in dependencies) {
      _addDep(dependency);
    }
  }

  @override
  _initController() {
    final controller = super._initController();

    controller.onListen = () {
      if (_watchers.isEmpty) {
        for (final dep in _deps) {
          dep._addWatcher(this);
        }
      }
    };
    controller.onCancel = () {
      if (_watchers.isEmpty) {
        for (final dep in _deps) {
          dep._removeWatcher(this);
        }
      }
    };

    return controller;
  }

  void _addDep(Computable dep) {
    _deps.add(dep);

    if (isActive) {
      dep._addWatcher(this);
    }
  }

  void _removeDep(Computable dep) {
    _deps.remove(dep);
    _depsCache.remove(dep);

    if (isActive) {
      dep._removeWatcher(this);
    }
  }

  @override
  _addWatcher(watcher) {
    if (!isActive) {
      for (final dependency in _deps) {
        dependency._addWatcher(this);
      }
    }

    super._addWatcher(watcher);
  }

  @override
  _removeWatcher(watcher) {
    super._removeWatcher(watcher);

    if (!isActive) {
      for (final dep in _deps) {
        dep._removeWatcher(this);
      }
    }
  }

  @override
  get isDirty {
    return _deps.any(
      (dep) => !_depsCache.containsKey(dep) || _depsCache[dep] != dep.get(),
    );
  }

  // Schedules an asynchronous broadcast of its recomputed value to its stream listeners
  // and computable watchers. Scheduling this recomputation asynchronously has a couple advantages:
  //
  // 1. It batches together synchronous updates to multiple dependencies into a single event.
  // 2. It frees up the main isolate to process other pending events before having to perform what could
  //    be a heavy recomputation.
  void _scheduleBroadcast() {
    if (_isScheduled) {
      return;
    }

    _isScheduled = true;

    Future.delayed(Duration.zero, () {
      // Rather than call [_cachedRecompute] directly, [get] is used to determine if the computable still needs to be recomputed,
      // since it may already have performed the recomputation after it was scheduled.
      add(get());
      _isScheduled = false;
    });
  }

  @override
  get() {
    if (isDirty) {
      // If it is active, it schedules a an asynchronous broadcast of its recomptued value.
      if (isActive) {
        _scheduleBroadcast();
      }

      // Cache the latest values of the computable's dependencies.
      for (final dep in _deps) {
        _depsCache[dep] = dep.get();
      }

      // Since the computable was accessed while dirty, it must immediately recompute its value.
      _value = _recompute();
    }

    return _value;
  }

  int get depLength {
    return _deps.length;
  }

  T _recompute();
}
