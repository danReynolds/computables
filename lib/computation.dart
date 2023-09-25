part of 'computables.dart';

/// A [Computation] is used to derive data from the composition of multiple [Computable] inputs.
class Computation<T> with ComputableMixin<T> implements Computable<T> {
  final List<Computable> computables;
  final T Function(List inputs) compute;

  final List<StreamSubscription> _subscriptions = [];
  late List _computableValues;
  int _completedSubscriptionCount = 0;

  Computation({
    required this.computables,
    required this.compute,
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
            add(compute(_computableValues));
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

    init(compute(_computableValues), broadcast: broadcast);
  }

  @override
  get() {
    return compute(computables.map((computable) => computable.get()).toList());
  }
}
