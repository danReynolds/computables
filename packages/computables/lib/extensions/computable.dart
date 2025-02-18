part of '../computables.dart';

extension ComputableExtensions<T> on Computable<T> {
  Computation<S> map<S>(
    S Function(T value) map, {
    bool broadcast = false,
    bool? dedupe,
  }) {
    return Computation(
      computables: [this],
      compute: (inputs) => map(inputs.first),
      broadcast: broadcast,
      dedupe: dedupe ?? this.dedupe,
    );
  }

  ComputationTransform<S> transform<S>(
    Computable<S> Function(T value) transform, {
    bool broadcast = false,
    bool? dedupe,
  }) {
    return ComputationTransform(
      computables: [this],
      transform: (inputs) => transform(inputs.first),
      broadcast: broadcast,
      dedupe: dedupe ?? this.dedupe,
    );
  }
}
