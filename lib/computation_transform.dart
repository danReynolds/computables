part of 'computables.dart';

/// A [ComputationTransform] subscribes to a set of input computables and derives
/// a new output computable from their inputs using the provided [transform] function.
class ComputationTransform<T> extends Computable<T> with Recomputable<T> {
  final Computation<Computable<T>> _computation;
  Computable<T>? _innerComputable;

  ComputationTransform({
    required List<Computable> computables,
    required Computable<T> Function(List inputs) transform,
    super.broadcast = false,
    super.dedupe = false,
  })  : _computation =
            Computation(computables: computables, compute: transform),
        super._() {
    init([_computation]);
  }

  @override
  _recompute() {
    final innerComputable = _computation.get();

    /// A computation transform could be recomputing because either its inner computable
    /// has emitted a new value or its inner computable has changed. If the inner computable has changed,
    /// then it disposes the previous inner computable, removing it from its dependencies and switches to the new one.
    ///
    /// In either scenario, it then returns the inner computable's latest value.
    if (identical(innerComputable, _innerComputable)) {
      return innerComputable.get();
    }

    _addDep(innerComputable);

    if (_innerComputable != null) {
      _removeDep(_innerComputable!);
    }

    _innerComputable = innerComputable;

    return innerComputable.get();
  }
}
