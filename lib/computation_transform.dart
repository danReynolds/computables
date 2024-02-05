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
    _innerSubscription?.cancel();
    _innerSubscription = _computation.get()._syncStream().listen(add);
    add(_computation.get().get());
  }

  @override
  dispose() {
    super.dispose();

    _subscription.cancel();
    _innerSubscription?.cancel();
  }
}
