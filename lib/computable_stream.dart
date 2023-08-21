part of 'computables.dart';

class ComputableStream<T> with ComputableMixin<T> implements Computable<T> {
  ComputableStream(
    Stream<T> stream, {
    required T initialValue,
    bool broadcast = false,
  }) {
    StreamSubscription<T>? subscription;

    subscription = stream.listen(
      (value) => add(value),
      onDone: () {
        subscription!.cancel();
        dispose();
      },
    );

    init(initialValue, broadcast: broadcast);
  }
}
