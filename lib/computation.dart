part of 'computables.dart';

/// A computation combines one or more computables into a new computable
/// that emits the resolved values of the comptuation. It automatically recomputes
/// whenever any of its dependencies are updated.
class Computation<T> extends Computable<T> {
  final T Function() _compute;
  final Set<Computable> _dependencies = {};
  final Map<Computable, StreamSubscription> _subscriptions = {};

  Computation(
    this._compute, {
    bool broadcast = false,
  }) : super._(broadcast: broadcast) {
    _recompute();
  }

  void _subscribe(Computable computable) {
    _dependencies.add(computable);
    _subscriptions[computable] ??= computable._syncStream().listen((_) {
      _recompute();
    });
  }

  void _recompute() {
    // If a computation is being recomputed in the context of one of its own dependencies, then this is a cyclical
    // dependency and the recomputation should be logged and aborted.
    if (_context != null && _dependencies.contains(_context)) {
      printDebug(
        'Cyclical dependency $_context detected during recomputation of: $this',
      );
      return;
    }

    final prevDependencies = {..._dependencies};
    _dependencies.clear();

    _context = this;
    final recomputedValue = _compute();

    final staleDeps = prevDependencies.difference(_dependencies);

    for (final dep in staleDeps) {
      _subscriptions[dep]!.cancel();
      _subscriptions.remove(dep);
    }

    add(recomputedValue);

    // The context is only cleared *after* synchronously informing dependents in `add()` so that they
    // can check whether this computation is also dependent on them and detect cycles.
    _context = null;
  }

  @override
  dispose() {
    super.dispose();

    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
  }

  static Computation<T> compute<T>(
    T Function() compute, {
    bool broadcast = false,
  }) {
    return Computation<T>(
      compute,
      broadcast: broadcast,
    );
  }

  static Computation<T> compute2<T, S1, S2>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    T Function(S1 input1, S2 input2) compute, {
    bool broadcast = false,
  }) {
    return Computation<T>(
      () => compute(computable1.get(), computable2.get()),
      broadcast: broadcast,
    );
  }

  static Computation<T> compute3<T, S1, S2, S3>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    T Function(S1 input1, S2 input2, S3 input3) compute, {
    bool broadcast = false,
  }) {
    return Computation<T>(
      () => compute(computable1.get(), computable2.get(), computable3.get()),
      broadcast: broadcast,
    );
  }

  static Computation<T> compute4<T, S1, S2, S3, S4>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<S4> computable4,
    T Function(S1 input1, S2 input2, S3 input3, S4 input4) compute, {
    bool broadcast = false,
  }) {
    return Computation<T>(
      () => compute(
        computable1.get(),
        computable2.get(),
        computable3.get(),
        computable4.get(),
      ),
      broadcast: broadcast,
    );
  }

  static ComputationTransform<T> transform<T>(
    Computable<T> Function() transform, {
    bool broadcast = false,
  }) {
    return ComputationTransform<T>(
      transform,
      broadcast: broadcast,
    );
  }

  static Computable<T> transform2<T, S1, S2>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<T> Function(S1 input1, S2 input2) transform, {
    bool broadcast = false,
    bool dedupe = false,
  }) {
    return ComputationTransform<T>(
      () => transform(computable1.get(), computable2.get()),
      broadcast: broadcast,
    );
  }

  static Computable<T> transform3<T, S1, S2, S3>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<T> Function(S1 input1, S2 input2, S3 input3) transform, {
    bool broadcast = false,
    bool dedupe = false,
  }) {
    return ComputationTransform<T>(
      () => transform(computable1.get(), computable2.get(), computable3.get()),
      broadcast: broadcast,
    );
  }

  static Computable<T> transform4<T, S1, S2, S3, S4>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<S4> computable4,
    Computable<T> Function(
      S1 input1,
      S2 input2,
      S3 input3,
      S4 input4,
    ) transform, {
    bool broadcast = false,
  }) {
    return ComputationTransform<T>(
      () => transform(
        computable1.get(),
        computable2.get(),
        computable3.get(),
        computable4.get(),
      ),
      broadcast: broadcast,
    );
  }
}
