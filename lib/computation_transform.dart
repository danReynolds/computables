part of 'computables.dart';

/// A [ComputationTransform] transforms the input computables of a [Computation] into an output [Computable] and subscribes to it.
class ComputationTransform<T> extends Computable<T> {
  late final Computable<Computable<T>> _computation;
  late final StreamSubscription<Computable<T>> _subscription;
  StreamSubscription<T>? _innerSubscription;

  ComputationTransform(
    Computable<T> Function() transform, {
    bool broadcast = false,
  }) : super._(broadcast: broadcast) {
    _computation = Computation(transform);

    _subscription = _computation._syncStream().listen((_) {
      _resubscribe();
    });

    _resubscribe();
  }

  void _resubscribe() {
    // The computation transform marks itself as the current computable context ahead of
    // informing dependents of its new value so that they are able to detect a cyclical dependency to this computable.
    _context = this;

    _innerSubscription?.cancel();
    final innerComputation = _computation.get();
    _innerSubscription = innerComputation._syncStream().listen(add);

    add(innerComputation.get());

    _context = null;
  }

  @override
  dispose() {
    super.dispose();

    _subscription.cancel();
    _innerSubscription?.cancel();
  }
}
