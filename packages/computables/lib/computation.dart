part of 'computables.dart';

/// A [Computation] combines the values of one or more input computables into a single output
/// value using the provided [compute] function.
///
/// Since calculating a [compute] function can be expensive, a computation's value is is *lazy*, only recomputing
/// if it is dirty and has an active listener.
class Computation<T> extends Computable<T> with Dependencies<T> {
  /// The compute function that computes the derived value of this computable from its input computables.
  final T Function(List inputs) compute;

  /// The list of input computables that this computation computes its value from.
  final List<Computable> computables;

  Computation({
    required this.computables,
    required this.compute,
    super.broadcast = false,
    super.dedupe = true,
  }) : super._() {
    for (final dependency in computables) {
      _addDependency(dependency);
    }
  }

  /// A cache of the the latest values of this computable's dependencies.
  final Map<Computable, dynamic> _dependenciesCache = {};

  /// A global resolver cache is used during the resolution of a computation's value via [get]. It caches the value of computables
  /// reached during dependency resolution to prevent duplicate recomputation of expensive recomputables reachable from the
  /// computation's dependency graph.
  static Map? _resolverCache;

  /// Resolves a dependency, caching it in the current computation's global resolution cache.
  dynamic _resolveDependency(Computable dependency) {
    return _resolverCache![dependency] ??= dependency.get();
  }

  /// Computations recompute their value lazily, so they can be considered dirty if any of their
  /// dependencies have changed and the computation has not recomputed its value yet.
  get isDirty {
    return _dependencies.length != _dependenciesCache.length ||
        _dependencies
            .any((dep) => _dependenciesCache[dep] != _resolveDependency(dep));
  }

  @override
  _removeDependency(Computable dependency) {
    super._removeDependency(dependency);
    _dependenciesCache.remove(dependency);
  }

  @override
  get() {
    bool isRootResolver = false;
    switch (_resolverCache) {
      // If this computable is the root of the current resolution, then it is responsible for
      // initializing and disposing of the resolver cache.
      case null:
        _resolverCache = {};
        isRootResolver = true;
        break;
      case Map cache when cache.containsKey(this):
        return cache[this];
    }

    try {
      if (isDirty) {
        // If it is active, it schedules an asynchronous broadcast of its recomputed value.
        if (isActive) {
          _scheduleBroadcast();
        }

        // Cache the updated values of the computation's dependencies.
        for (final dep in _dependencies) {
          _dependenciesCache[dep] = _resolveDependency(dep);
        }

        // Since the computation's value has been synchronously requested, it must immediately recompute its value.
        _value =
            compute(computables.map((computable) => computable.get()).toList());
      }

      return _value;
    } finally {
      // Whether the resolution of the computation's value succeeds or throws an exception, the resolver cache
      // must always be cleared afterwards.
      if (isRootResolver) {
        _resolverCache = null;
      }
    }
  }
}
