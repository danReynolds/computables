part of 'computables.dart';

typedef Optional<T> = T?;

class Computable<T> with ComputableMixin<T> {
  Computable(
    T initialValue, {
    bool broadcast = false,
  }) {
    init(initialValue, broadcast: broadcast);
  }

  static Computable<S> fromValue<S>(
    S initialValue, {
    bool broadcast = false,
  }) {
    return Computable<S>(initialValue, broadcast: broadcast);
  }

  static Computable<S> fromIterable<S>(
    Iterable<S> iterable, {
    bool broadcast = false,
  }) {
    if ((S != Optional<S>) && iterable.isEmpty) {
      throw 'missing iterable value for non-nullable type.';
    }

    final computable = Computable(iterable.first, broadcast: broadcast);
    for (final value in iterable.skip(1)) {
      computable.add(value);
    }

    return computable;
  }

  static Computable<S> fromFuture<S>(
    Future<S> future, {
    S? initialValue,
    bool broadcast = false,
  }) {
    if ((S != Optional<S>) && initialValue == null) {
      throw 'missing [initialValue] for non-nullable type.';
    }

    return ComputableFuture<S>(
      future,
      initialValue: initialValue as S,
      broadcast: broadcast,
    );
  }

  static Computable<S> fromStream<S>(
    Stream<S> stream, {
    S? initialValue,
    bool broadcast = false,
  }) {
    if ((S != Optional<S>) && initialValue == null) {
      throw 'missing [initialValue] for non-nullable type';
    }

    return ComputableStream<S>(
      stream,
      initialValue: initialValue as S,
      broadcast: broadcast,
    );
  }

  static Computable<T> compute1<T, S1>(
    Computable<S1> computable1,
    T Function(S1 input1) compute, {
    bool broadcast = false,
  }) {
    return Computation<T>(
      computables: [computable1],
      compute: (inputs) => compute(inputs[0]),
      broadcast: broadcast,
    );
  }

  static Computable<T> compute2<T, S1, S2>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    T Function(S1 input1, S2 input2) compute, {
    bool broadcast = false,
  }) {
    return Computation<T>(
      computables: [computable1, computable2],
      compute: (inputs) => compute(inputs[0], inputs[1]),
      broadcast: broadcast,
    );
  }

  static Computable<T> compute3<T, S1, S2, S3>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    T Function(S1 input1, S2 input2, S3 input3) compute, {
    bool broadcast = false,
  }) {
    return Computation<T>(
      computables: [computable1, computable2, computable3],
      compute: (inputs) => compute(inputs[0], inputs[1], inputs[2]),
      broadcast: broadcast,
    );
  }

  static Computation<T> compute4<T, S1, S2, S3, S4>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<S3> computable4,
    T Function(
      S1 input1,
      S2 input2,
      S3 input3,
      S4 input4,
    ) compute, {
    bool broadcast = false,
  }) {
    return Computation<T>(
      computables: [computable1, computable2, computable3, computable4],
      compute: (inputs) => compute(inputs[0], inputs[1], inputs[2], inputs[3]),
      broadcast: broadcast,
    );
  }

  static Computable<T> transform1<T, S1>(
    Computable<S1> computable1,
    Computable<T> Function(S1 input1) transform, {
    bool broadcast = false,
  }) {
    return ComputationTransform<T>(
      computables: [computable1],
      transform: (inputs) => transform(inputs[0]),
      broadcast: broadcast,
    );
  }

  static Computable<T> transform2<T, S1, S2>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<T> Function(S1 input1, S2 input2) transform, {
    bool broadcast = false,
  }) {
    return ComputationTransform<T>(
      computables: [computable1, computable2],
      transform: (inputs) => transform(inputs[0], inputs[1]),
      broadcast: broadcast,
    );
  }

  static Computable<T> transform3<T, S1, S2, S3>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<T> Function(S1 input1, S2 input2, S3 input3) transform, {
    bool broadcast = false,
  }) {
    return ComputationTransform<T>(
      computables: [computable1, computable2, computable3],
      transform: (inputs) => transform(inputs[0], inputs[1], inputs[2]),
      broadcast: broadcast,
    );
  }

  static Computable<T> transform4<T, S1, S2, S3, S4>(
    Computable<S1> computable1,
    Computable<S2> computable2,
    Computable<S3> computable3,
    Computable<S4> computable4,
    Computable<T> Function(
      S1 input1,
      S2 input2,
      S3 input3,
      S4 input4,
    ) transform, {
    bool broadcast = false,
  }) {
    return ComputationTransform<T>(
      computables: [computable1, computable2, computable3, computable4],
      transform: (inputs) =>
          transform(inputs[0], inputs[1], inputs[2], inputs[3]),
      broadcast: broadcast,
    );
  }

  static ComputableSubscriber<T> subscriber<T>({
    T? initialValue,
    bool broadcast = false,
  }) {
    return ComputableSubscriber<T>(
      initialValue: initialValue,
      broadcast: broadcast,
    );
  }
}
