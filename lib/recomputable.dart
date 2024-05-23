part of computables;

/// A mixin that implements the recomputable behavior used by a [Computation] and [ComputationTransform].
mixin Recomputable<T> on Computable<T> {
  bool _isDirty = false;
  T? _pendingValue;

  final Set<Computable> _dependencies = {};

  @override
  get isDirty {
    return _isDirty || _dependencies.any((dep) => dep.isDirty);
  }

  void _init(List<Computable> computables) {
    _value = _recompute();
  }

  void _dirty() {
    if (!_isDirty) {
      _isDirty = true;

      for (final dep in _dependents) {
        dep._dirty();
      }

      scheduleMicrotask(() {
        add(_pendingValue ?? _recompute());
        _isDirty = false;
        _pendingValue = null;
      });
    }
  }

  @override
  get() {
    if (isDirty) {
      /// If a computable marked as dirty is accessed ahead of its scheduled broadcast, then it must recompute immediately
      /// and cache the updated value so that when its scheduled broadcast runs, it doesn't need to recompute again.
      return _pendingValue = _recompute();
    }

    return _value;
  }

  T _recompute();
}
