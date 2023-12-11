part of 'computables.dart';

class ComputableFuture<T> extends Computable<T> {
  final Future<T> future;

  ComputableFuture(
    this.future, {
    required T initialValue,
    bool broadcast = false,
  })  : assert(
          initialValue != null || T == Optional<T>,
          'ComputableFuture must specify a nullable type or an initial value.',
        ),
        super(
          initialValue,
          broadcast: broadcast,
        ) {
    future.then(add);
  }

  @override
  get() {
    return _value;
  }
}
