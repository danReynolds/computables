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
    _computation._dependents.add(this);
    init(computables);
  }

  @override
  _recompute() {
    final innerComputable = _computation.get();

    /// A computation transform could have been marked as dirty either because its inner computable
    /// has a new value or its computation has a new inner computable. If the inner computable has changed,
    /// then it removes its dependency on the previous computable and switches to the new one.
    ///
    /// In either scenario, it then returns the inner computable's latest value.
    if (identical(innerComputable, _innerComputable)) {
      return innerComputable.get();
    }

    _innerComputable?.dispose();
    _innerComputable = innerComputable;

    innerComputable._dependents.add(this);

    return innerComputable.get();
  }

  @override
  dispose() {
    _computation.dispose();
    super.dispose();
  }
}
