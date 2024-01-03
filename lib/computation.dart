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

    return Computation._(
      computables: computables,
      compute: compute,
      initialComputableValues: initialValues,
      broadcast: broadcast,
      dedupe: dedupe,
    );
  }

  Computation._({
    required this.computables,
    required this.compute,
    required List initialComputableValues,
    required bool broadcast,
    required bool dedupe,
  })  : _computableValues = initialComputableValues,
        super(
          compute(initialComputableValues),
          broadcast: broadcast,
          dedupe: dedupe,
        ) {
    for (int i = 0; i < computables.length; i++) {
      final computable = computables[i];

      _subscriptions.add(
        computable._syncStream().listen((inputValue) {
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
  dispose() {
    super.dispose();

    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
  }
}
