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
    init(computables);

    for (final computable in computables) {
      computable._dependents.add(this);
    }
  }

  @override
  T _recompute() {
    return compute(computables.map((computable) => computable.get()).toList());
  }

  @override
  dispose() {
    for (final computable in computables) {
      computable._dependents.remove(this);

      if (!computable.broadcast) {
        computable.dispose();
      }
    }

    super.dispose();
  }
}
