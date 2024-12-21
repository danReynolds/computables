part of 'computables.dart';

/// A [Computation] subscribes to a set of input computables and derives an output
/// value from their inputs using the provided [compute] function.
class Computation<T> extends Computable<T> with Recomputable<T> {
  final T Function(List inputs) compute;

  /// The list of computables that the computation was instantiated with.
  final List<Computable> computables;

  Computation({
    required this.computables,
    required this.compute,
    super.broadcast = false,
    super.dedupe = false,
  }) : super._() {
    _initDeps(computables);
  }

  @override
  T _recompute() {
    return compute(computables.map((computable) => computable.get()).toList());
  }
}
