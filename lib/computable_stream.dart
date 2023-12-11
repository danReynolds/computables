part of 'computables.dart';

class ComputableStream<T> extends Computable<T> {
  ComputableStream(
    Stream<T> stream, {
    required T initialValue,
    bool broadcast = false,
  }) : super(initialValue, broadcast: broadcast) {
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
