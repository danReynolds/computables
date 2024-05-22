part of computables;

/// A mixin that implements the recomputable behavior used by a [Computation] and [ComputationTransform].
mixin Recomputable<T> on Computable<T> {
  late final List<Computable> computables;

  /// A cached value of the recomputed value pending broadcast.
  T? _pendingValue;

  bool _isDirty = false;

  bool get isDirty {
    return _isDirty;
  }

  set isDirty(bool isDirty) {
    // On marking the computable as dirty, schedule a broadcast to emit the recomputed value and mark
    // all of its dependents as dirty.
    if (!_isDirty && isDirty) {
      for (final dep in _dependents) {
        dep.isDirty = true;
      }

      scheduleMicrotask(() {
        add(get());
        _pendingValue = null;
      });
    }

    _isDirty = isDirty;
  }

  void init(List<Computable> computables) {
    this.computables = computables;
    _value = _recompute();
  }

  @override
  get() {
    if (isDirty) {
      isDirty = false;

      /// If a computable marked as dirty is accessed ahead of its scheduled broadcast, then it must recompute immediately
      /// and cache the updated value so that when its scheduled broadcast runs, it doesn't need to recompute again.
      return _pendingValue = _recompute();
    }

    return _pendingValue ?? _value;
  }

  T _recompute();
}
