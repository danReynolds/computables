part of computables;

/// A mixin that implements the recomputable behavior used by a [Computation] and [ComputationTransform].
mixin Recomputable<T> on Computable<T> {
  bool _isDirty = false;
  final Set<Computable> _dependencies = {};

  @override
  get isDirty {
    return _isDirty || _dependencies.any((dep) => dep.isDirty);
  }

  void _dirty() {
    if (!_isDirty) {
      _isDirty = true;

      Future.delayed(Duration.zero, () {
        add(_recompute());
        _isDirty = false;
      });
    }
  }

  @override
  get() {
    if (isDirty) {
      return _recompute();
    }

    return _value;
  }

  T _recompute();
}
