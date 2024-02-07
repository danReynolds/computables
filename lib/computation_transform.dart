part of 'computables.dart';

/// A [ComputationTransform] transforms the input computables of a [Computation] into an output [Computable] and subscribes to it.
class ComputationTransform<T> extends Computable<T> {
  final List<Computable> computables;
  final Computable<T> Function(List inputs) transform;
  late final Computable<Computable<T>> _computation;
  late final StreamSubscription<Computable<T>> _subscription;
  StreamSubscription<T>? _innerSubscription;

  ComputationTransform({
    required this.computables,
    required this.transform,
    super.broadcast = false,
  }) : super._() {
    _computation = Computation(computables: computables, compute: transform);

    _subscription = _computation._syncStream().listen((_) {
      _recompute();
    });

    _recompute();
  }

  void _recompute() {
    final innerComputable = _computation.get();
    _innerSubscription?.cancel();
    _innerSubscription = innerComputable._syncStream().listen((value) {
      add(value);
    });
    add(innerComputable.get());
  }

  @override
  dispose() {
    super.dispose();

    _computation.dispose();
    _subscription.cancel();
    _innerSubscription?.cancel();
  }
}
