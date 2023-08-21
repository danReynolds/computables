part of 'computables.dart';

class ComputableFuture<T> with ComputableMixin<T> implements Computable<T> {
  final Future<T> future;

  ComputableFuture(
    this.future, {
    required T initialValue,
    bool broadcast = false,
  }) {
    assert(
      initialValue != null || T == Optional<T>,
      'ComputableFuture must specify a nullable type or an initial value.',
    );

    future.then(add);

    init(initialValue, broadcast: broadcast);
  }

  @override
  get() {
    return _value;
  }
}
