part of 'computables.dart';

class ComputableStream<T> extends Computable<T> {
  late final StreamSubscription<T> _subscription;

  ComputableStream(
    Stream<T> stream, {
    required T initialValue,
  })  : assert(
          initialValue != null || T == _Optional<T>,
          'ComputableStream must specify a nullable type or an initial value.',
        ),
        super(initialValue) {
    _subscription = stream.listen(add, onDone: () {
      dispose();
    });
  }

  @override
  dispose() {
    super.dispose();
    _subscription.cancel();
  }
}
