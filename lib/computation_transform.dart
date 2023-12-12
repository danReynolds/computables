part of 'computables.dart';

/// A [ComputationTransform] transforms the input computables of a [Computation] into an output [Computable] and subscribes to it.
class ComputationTransform<T> extends Computable<T> {
  final List<Computable> computables;
  final Computable<T> Function(List inputs) _transform;

  late Computable<T> _innerComputation;
  StreamSubscription<T>? _innerComputationSubscription;

  final List<StreamSubscription> _subscriptions = [];
  late List _computableValues;
  int _completedSubscriptionCount = 0;

  factory ComputationTransform({
    required List<Computable> computables,
    required Computable<T> Function(List inputs) transform,
    bool broadcast = false,
    bool dedupe = false,
  }) {
    final initialValues =
        computables.map((computable) => computable.get()).toList();
    final initialComputation = transform(initialValues);

    return ComputationTransform._(
      computables: computables,
      transform: transform,
      initialComputableValues: initialValues,
      initialComputation: initialComputation,
      broadcast: broadcast,
      dedupe: dedupe,
    );
  }

  ComputationTransform._({
    required this.computables,
    required Computable<T> Function(List inputs) transform,
    required List initialComputableValues,
    required Computable<T> initialComputation,
    required bool broadcast,
    required bool dedupe,
  })  : _transform = transform,
        _computableValues = initialComputableValues,
        _innerComputation = initialComputation,
        super(
          initialComputation.get(),
          broadcast: broadcast,
          dedupe: dedupe,
        ) {
    for (int i = 0; i < computables.length; i++) {
      final computable = computables[i];

      _subscriptions.add(
        /// Skip the current value emitted by each [Computable] since the first computation value
        /// is pre-computed as one initial update.
        computable.stream().skip(1).listen((inputValue) {
          _computableValues[i] = inputValue;
          _innerComputationSubscription?.cancel();
          _innerComputation = _transform(_computableValues);
          _innerComputationSubscription =
              _innerComputation.stream().listen(add);
        }, onDone: () {
          _completedSubscriptionCount++;
          if (_completedSubscriptionCount == _subscriptions.length) {
            dispose();
          }
        }),
      );
    }

    /// Skip the first event since it will be emitted by [init].
    _innerComputationSubscription =
        _innerComputation.stream().skip(1).listen(add);
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
      return _transform(values).get();
    }

    return _value;
  }
}
