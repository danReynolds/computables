part of 'computables.dart';

/// A [Computation] is used to derive data from the composition of multiple [Computable] inputs.
class Computation<T> extends Computable<T> {
  final List<Computable> computables;
  final T Function(List inputs) compute;
  final List<StreamSubscription> _subscriptions = [];

  Computation({
    required this.computables,
    required this.compute,
    super.broadcast = false,
  }) : super._() {
    for (final computable in computables) {
      StreamSubscription? subscription;

      subscription = computable._syncStream().listen((inputValue) {
        _recompute();
      }, onDone: () {
        _subscriptions.remove(subscription);
        if (_subscriptions.isEmpty) {
          dispose();
        }
      });

      _subscriptions.add(subscription);
    }

    _recompute();
  }

  T _recompute() {
    return add(
      compute(
        computables.map((computable) => computable.get()).toList(),
      ),
    );
  }

  @override
  dispose() {
    super.dispose();

    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
  }
}
