part of 'computables.dart';

/// A [Computation] is used to derive data from the composition of multiple [Computable] inputs.
class Computation<T> extends Computable<T> {
  final List<Computable> computables;
  final T Function(List inputs) compute;

  final List<StreamSubscription> _subscriptions = [];
  late List _computableValues;
  int _completedSubscriptionCount = 0;

  factory Computation({
    required List<Computable> computables,
    required T Function(List inputs) compute,
    bool broadcast = false,
    bool dedupe = false,
  }) {
    final initialValues =
        computables.map((computable) => computable.get()).toList();
    final initialValue = compute(initialValues);

    return Computation._(
      computables: computables,
      compute: compute,
      initialComputableValues: initialValues,
      initialValue: initialValue,
      broadcast: broadcast,
      dedupe: dedupe,
    );
  }

  Computation._({
    required initialValue,
    required this.computables,
    required this.compute,
    required List initialComputableValues,
    required bool broadcast,
    required bool dedupe,
  })  : _computableValues = initialComputableValues,
        super(
          initialValue,
          broadcast: broadcast,
          dedupe: dedupe,
        ) {
    for (int i = 0; i < computables.length; i++) {
      final computable = computables[i];

      _subscriptions.add(
        /// Skip the current value emitted by each [Computable] since the first computation value
        /// is pre-computed as one initial update by the call to [init].
        computable.stream().skip(1).listen((inputValue) {
          _computableValues[i] = inputValue;
          add(compute(_computableValues));
        }, onDone: () {
          _completedSubscriptionCount++;
          if (_completedSubscriptionCount == _subscriptions.length) {
            dispose();
          }
        }),
      );
      _computableValues[i] = computables[i].get();
    }
  }

  @override
  get() {
    final values = computables.map((computable) => computable.get()).toList();
    bool shouldUpdate = false;

    for (int i = 0; i < computables.length; i++) {
      if (_computableValues[i] != values[i]) {
        shouldUpdate = true;
        break;
      }
    }

    if (shouldUpdate) {
      return compute(values);
    }

    return _value;
  }
}
