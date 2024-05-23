part of 'computables.dart';

/// A [Computation] subscribes to a set of input computables and derives an output
/// value from their inputs using the provided [compute] function.
class Computation<T> extends Computable<T> with Recomputable<T> {
  final T Function(List inputs) compute;

  Computation({
    required List<Computable> computables,
    required this.compute,
    super.broadcast = false,
    super.dedupe = false,
  }) : super._() {
    for (final computable in computables) {
      _dependencies.add(computable);
      computable._dependents.add(this);
    }

    _init(computables);
  }

  @override
  T _recompute() {
    return compute(
      _dependencies.map((computable) => computable.get()).toList(),
    );
  }

  @override
  dispose() {
    for (final dep in _dependencies) {
      if (!dep.broadcast) {
        dep.dispose();
      } else {
        dep._dependents.remove(this);
      }
    }

    super.dispose();
  }
}
