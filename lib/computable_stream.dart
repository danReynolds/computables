part of 'computables.dart';

class ComputableStream<T> extends Computable<T> {
  ComputableStream(
    Stream<T> stream, {
    required T initialValue,
    bool broadcast = false,
    bool dedupe = false,
  })  : assert(
          initialValue != null || T == Optional<T>,
          'ComputableStream must specify a nullable type or an initial value.',
        ),
        super(
          initialValue,
          broadcast: broadcast,
          dedupe: dedupe,
        ) {
    StreamSubscription<T>? subscription;

    subscription = stream.listen(
      (value) => add(value),
      onDone: () {
        subscription!.cancel();
        dispose();
      },
    );
  }
}
