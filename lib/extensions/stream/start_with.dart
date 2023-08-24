part of computables;

StreamTransformer<T, T> startWithStreamTransformer<T>(T event) {
  return createTransformer<T, T>(onListen: (controller) {
    controller.add(event);
  });
}

extension StartWith on Stream {
  Stream<T> startWith<T>(T event) {
    return transform(startWithStreamTransformer<T>(event));
  }
}
