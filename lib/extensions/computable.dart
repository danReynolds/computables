part of computables;

extension ComputableExtensions<T> on Computable<T> {
  Computation<S> map<S>(
    S Function(T value) map, {
    bool broadcast = false,
  }) {
    return Computation(() => map(get()), broadcast: broadcast);
  }

  ComputationTransform<S> transform<S>(
    Computable<S> Function(T value) transform, {
    bool broadcast = false,
  }) {
    return ComputationTransform(
      () => transform(get()),
      broadcast: broadcast,
    );
  }
}
