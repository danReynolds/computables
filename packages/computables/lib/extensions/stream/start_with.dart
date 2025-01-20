part of '../../computables.dart';

StreamTransformer<T, T> startWithStreamTransformer<T>(T event) {
  return createTransformer<T, T>(
    onListen: (controller) {
      controller.add(event);
    },
  );
}

extension StartWith<T> on Stream<T> {
  Stream<T> startWith(T event) {
    return transform(startWithStreamTransformer<T>(event));
  }
}
