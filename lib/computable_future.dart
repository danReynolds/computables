part of 'computables.dart';

class ComputableFuture<T> extends Computable<T> {
  final Future<T> future;

  ComputableFuture(
    this.future, {
    required T initialValue,
    bool broadcast = false,
    bool dedupe = true,
  })  : assert(
          initialValue != null || T == _Optional<T>,
          'ComputableFuture must specify a nullable type or an initial value.',
        ),
        super(
          initialValue,
          dedupe: dedupe,
          broadcast: broadcast,
        ) {
    future.then(add);
  }
}
