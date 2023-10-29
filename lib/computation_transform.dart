part of 'computables.dart';

/// A [ComputationTransform] transforms the input computables of a [Computation] into an output [Computable] and subscribes to it.
class ComputationTransform<T> with ComputableMixin<T> implements Computable<T> {
  final List<Computable> computables;
  final Computable<T> Function(List inputs) transform;

  late Computable<T> _innerComputation;
  StreamSubscription<T>? _innerComputationSubscription;

  final List<StreamSubscription> _subscriptions = [];
  late List _computableValues;
  int _completedSubscriptionCount = 0;

  ComputationTransform({
    required this.computables,
    required this.transform,
    required bool broadcast,
  }) {
    _computableValues = List.filled(computables.length, null);

    for (int i = 0; i < computables.length; i++) {
      final computable = computables[i];

      _subscriptions.add(
        /// Skip the current value emitted by each [Computable] since the first computation value
        /// is pre-computed as one initial update by the call to [init].
        computable.stream().skip(1).listen((inputValue) {
          if (_computableValues[i] != inputValue) {
            _computableValues[i] = inputValue;
            _recompute();
          }
        }, onDone: () {
          _completedSubscriptionCount++;
          if (_completedSubscriptionCount == _subscriptions.length) {
            dispose();
          }
        }),
      );
      _computableValues[i] = computables[i].get();
    }

    _innerComputation = transform(_computableValues);

    /// Skip the first event since it will be emitted by [init].
    _innerComputationSubscription =
        _innerComputation.stream().skip(1).listen(add);

    init(_innerComputation.get(), broadcast: broadcast);
  }

  T _recompute() {
    _innerComputationSubscription?.cancel();
    _innerComputation = transform(_computableValues);
    _innerComputationSubscription = _innerComputation.stream().listen(add);
    return _innerComputation.get();
  }

  @override
  get() {
    bool shouldRecompute = false;

    for (int i = 0; i < computables.length; i++) {
      final computable = computables[i];
      final computableValue = computable.get();

      if (_computableValues[i] != computableValue) {
        _computableValues[i] = computableValue;
        shouldRecompute = true;
      }
    }

    if (shouldRecompute) {
      return _recompute();
    }

    return _innerComputation.get();
  }
}
