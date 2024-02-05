part of 'computables.dart';

Computation? _context;

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

  T _recompute() {
    final prevDependencies = {..._dependencies};
    _dependencies.clear();

    _context = this;
    final recomputedValue = _compute();
    _context = null;

    final staleDeps = prevDependencies.difference(_dependencies);

    for (final dep in staleDeps) {
      _subscriptions[dep]!.cancel();
      _subscriptions.remove(dep);
    }

    add(recomputedValue);
    return recomputedValue;
  }

  @override
  dispose() {
    super.dispose();

    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
  }
}
