part of computables;

/// A mixin that implements the recomputable behavior used by a [Computation] and [ComputationTransform].
///
/// A recomputable can be either *active* or *inactive*.
///
/// Active:
/// An active recomputable is one that either has client stream listeners or dependent computables observing its changes.
/// Active computables **push** updates automatically and schedule a recomputation when they become dirty.
///
/// Inactive:
/// An inactive recomputable does not recompute automatically. Instead, it lazily recomputes its value when it is accessed.
///
/// All computables are inactive by default until a stream listener or computable observer is added.
mixin Recomputable<T> on Computable<T> {
  /// The dependencies of this computable.
  final Set<Computable> _deps = {};

  /// A cache of the values of the dependencies of this computable from this computable's most recent recomputation.
  final Map<Computable, dynamic> _depsCache = {};

  /// Whether this computation is scheduled to perform an asynchronous recomputation.
  bool _isScheduled = false;

  /// A global resolver cache is used during the resolution of a computable's value via [get]. It caches the value of computables
  /// reached during the dependency resolution to prevent duplicate re-accesses of computables reachable from this computable's dependency graph.
  static Map? _resolverCache;

  void _initDeps(List<Computable> dependencies) {
    for (final dependency in dependencies) {
      _addDep(dependency);
    }
  }

  @override
  _initController() {
    final controller = super._initController();

    controller.onListen = () {
      if (_observers.isEmpty) {
        for (final dep in _deps) {
          dep._addObserver(this);
        }
      }
    };
    controller.onCancel = () {
      if (_observers.isEmpty) {
        for (final dep in _deps) {
          dep._removeObserver(this);
        }
      }
    };

    return controller;
  }

  void _addDep(Computable dep) {
    _deps.add(dep);

    if (isActive) {
      dep._addObserver(this);
    }
  }

  void _removeDep(Computable dep) {
    _deps.remove(dep);
    _depsCache.remove(dep);

    if (isActive) {
      dep._removeObserver(this);
    }
  }

  @override
  _addObserver(obs) {
    if (!isActive) {
      for (final dependency in _deps) {
        dependency._addObserver(this);
      }
    }

    super._addObserver(obs);
  }

  @override
  _removeObserver(obs) {
    super._removeObserver(obs);

    if (!isActive) {
      for (final dep in _deps) {
        dep._removeObserver(this);
      }
    }
  }

  /// Resolves a depedency, caching it in the current resolution's global resolver cache.
  dynamic _resolveDep(Computable dep) {
    return _resolverCache![dep] ??= dep.get();
  }

  @override
  get isDirty {
    // If this resolution has already cached a value for this computable, then it cannot be dirty.
    if (_resolverCache!.containsKey(this)) {
      return false;
    }

    return _deps.length != _depsCache.length ||
        _deps.any((dep) => _depsCache[dep] != _resolveDep(dep));
  }

  // Schedules an asynchronous broadcast of its recomputed value to its stream listeners
  // and computable obss. Scheduling this recomputation asynchronously has a couple advantages:
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
    // If this computable is the root of the current [get] resolution, the it is responsible for
    // initializing and disposing of the resolver cache.
    bool isRootResolver = false;
    switch (_resolverCache) {
      case null:
        _resolverCache = {};
        isRootResolver = true;
        break;
      case Map cache when cache.containsKey(this):
        return cache[this];
    }

    if (isDirty) {
      // If it is active, it schedules an asynchronous broadcast of its recomputed value.
      if (isActive) {
        _scheduleBroadcast();
      }

      // Cache the updated values of the dependencies.
      for (final dep in _deps) {
        final resolvedDep = _resolveDep(dep);
        if (_depsCache[dep] != resolvedDep) {
          _depsCache[dep] = resolvedDep;
        }
      }

      // Since the computable was accessed while dirty, it must immediately recompute its value.
      _value = _recompute();
    }

    if (isRootResolver) {
      _resolverCache = null;
    }

    return _value;
  }

  int get depLength {
    return _deps.length;
  }

  T _recompute();
}
