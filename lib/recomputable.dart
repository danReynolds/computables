part of computables;

/// A mixin that implements the recomputable behavior used by a [Computation] and [ComputationTransform].
///
/// A recomputable can be either *active* or *inactive*.
///
/// Active:
/// An active recomputable is one that currently has listeners. Listeners can either be client listeners through the [stream] API, or
/// internal computable listeners that depend on it. On update, an active computable schedules its listeners
///
///
/// Inactive:
/// An inactive recomputable will mark itself as dirty but has no subscribers to notify and will therefore
/// not schedule itself for recomputation.
mixin Recomputable<T> on Computable<T> {
  final Set<Computable> _deps = {};
  final Map<Computable, dynamic> _depsCache = {};

  bool _isScheduled = false;

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
      if (_subscribers.isEmpty) {
        for (final dep in _depsCache.keys) {
          dep._removeSubscriber(this);
        }
      }
    };

    return controller;
  }

  void _addDep(Computable dep) {
    _deps.add(dep);

    if (isActive) {
      dep._addSubscriber(this);
    }
  }

  void _removeDep(Computable dep) {
    _deps.remove(dep);
    _depsCache.remove(dep);

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

    if (!isActive) {
      for (final dep in _depsCache.keys) {
        dep._removeSubscriber(this);
      }
    }
  }

  @override
  get isDirty {
    return _deps.any(
      (dep) => !_depsCache.containsKey(dep) || _depsCache[dep] != dep.get(),
    );
  }

  void _scheduleRecompute() {
    if (_isScheduled) {
      return;
    }

    _isScheduled = true;

    // A dirty recomputable is scheduled for recomputation asynchronously. This has a couple advantages:
    //
    // 1. It batches together synchronous updates to multiple dependencies into a single recomputation.
    // 2. It frees up the main isolate to process other pending events before having to perform what could
    //    be a heavy recomputation.
    Future.delayed(Duration.zero, () {
      add(get());
      _isScheduled = false;
    });
  }

  @override
  get() {
    if (isDirty) {
      // If it is active, it schedules a recomputation to notify its subscribers.
      if (isActive) {
        _scheduleRecompute();
      }

      // If accessed while dirty, the computable must immediately recompute its value.
      _cachedRecompute();
    }

    return _value;
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

    return _value = _recompute();
  }
}
