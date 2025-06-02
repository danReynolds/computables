part of 'computables.dart';

/// A [ComputationTransform] transforms a set of input computables into a single output
/// computable which it subscribes to and emits values from.
class ComputationTransform<T> extends Computable<T> with Dependencies<T> {
  final Computation<Computable<T>> _computation;
  Computable<T>? _innerComputable;

  ComputationTransform({
    required List<Computable> computables,
    required Computable<T> Function(List inputs) transform,
    super.dedupe = true,
  })  : _computation =
            Computation(computables: computables, compute: transform),
        super._() {
    _addDependency(_computation);
  }

  @override
  get() {
    final innerComputable = _computation.get();

    // On accessing the transform's value, if its inner computable has changed, then the
    // transform removes the old inner computable as a dependency and starts depending on the new one.
    if (!identical(_innerComputable, innerComputable)) {
      _addDependency(innerComputable);

      // The inner computable is not initialized until the first time the transform value is accessed,
      // in which case there is no previous dependency to remove.
      if (_innerComputable != null) {
        _removeDependency(_innerComputable!);
      }

      _innerComputable = innerComputable;
    }

    return innerComputable.get();
  }
}
