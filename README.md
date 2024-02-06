# Computables

Computables are streamable, composable values in Dart.

## Readable

The current value of a computable is synchronously readable using `get()`.

```dart
final computable = Computable(2);
print(computable.get()) // 2
computable.add(3);
print(computable.get()) // 3
```

## Streamable

The value of the computable can be reactively watched using `stream()`. The stream starts with
the current value of the computable.

```dart
import 'package:computables/computables.dart';

final computable = Computable(2);

computable.stream().listen((value) {
  print(value);
  // 2
  // 3
});

computable.add(3);
```

## Composable

A computation is a type of computable that composes multiple input computables into a single output computable. The input to a computation can be
any other computable value, including futures, streams and other computations.

```dart
final computable1 = Computable.fromStream(
  Stream.value(1),
  initialValue: 0,
);

final computable2 = Computable.fromFuture(
  Future.value(2),
  initialValue: 0,
);

final computation = Computation.compute(() => computable1.get() + computable2.get());

computation.stream().listen((value) {
  print(value);
  // 0
  // 1
  // 2
})
```

A computation automatically subscribes to all of the computables accessed in its computation and recalculates its value whenever any of them change.

If a computable stops being accessed in a computation, then it is unsubscribed from that computation, as shown below:

```dart
final computable1 = Computable(1);
final computable2 = Computable(2);

final computation = Computation.compute(() {
  final value1 = computable.get();

  if (value1 > 0) {
    return computable2.get();
  }

  return value1;
});

computation.stream().listen((value) {
  print(value);
  // 2
  // 0
});

// The recomputation triggered by updating the value of `computable1` to 0 causes `computable2` to no longer be referenced
// in the computation. As a result, the computation does not recompute when `computable2` is subsequently updated.
computable1.add(0);
computable2.add(3);
```

As a convenience, computations can also be expressed with a static list of inputs that automatically unwrap their values:

```dart
final computation = Computation.compute2(
  Computable.fromStream(Stream.value(1), initialValue: 0),
  Computable.fromFuture(Future.value(2), initialValue: 0),
  (input1, input2) => input1 + input2,
);

computable.stream().listen((value) {
  print(value);
  // 0
  // 1
  // 3
});
```

As mentioned previously, a computation is just another type of computable that can itself be immediately reused in other computations:

```dart
final computation = Computation.compute2(
  Computable.fromStream(Stream.value(1), initialValue: 0),
  Computable.fromFuture(Future.value(2), initialValue: 0),
  (input1, input2) => input1 + input2,
);

Computation.compute2(
  computation,
  Computable(1),
  (input1, input2) => input1 + input2,
).stream().listen((value) {
  print(value);
  // 1
  // 2
  // 4
});
```

## Transformable

A computation maps multiple input values to a single output value.

A transformation maps multiple input values to a new computable that can emit one or more values.

```dart
final computable1 = Computable(1);
final computable2 = Computable(5);

Computation.transform2(
  computable1,
  computable2,
  (input1, input2) {
    return Computable.fromStream(
      Stream.fromIterable(
        List.generate(input2 - input1, (index) => index + 1),
      ),
      initialValue: 0,
    );
  },
).stream.listen((value) {
  print(value);
  // 0
  // 1
  // 2
  // 3
  // 4
})
```

The above transformation takes two computable values as inputs and returns a computable stream of values
that begins with 0 and asynchronously emits the sequence 1, 2, 3, 4. 

## Extensions

There are some helpful utility extensions that make working with computables easier:

### Map

The map extension lets you rewrite a single input computation like this:

```dart
final computable = Computable(2);
Computation.compute(() => computable.get() + 1).stream().listen((value) {
  print(value);
  // 3
  // 4
});

computable.add(3);
```

as a direct mapping from the input computable:

```dart
final computable = Computable(2);
computable.map((value) => value + 1).stream().listen((value) {
  print(value);
  // 3
  // 4
});

computable.add(3);
```

### Transform

Single input transforms can also be written with an extension:

```dart
final computable = Computable(2);

computable.transform(
  (value) => Computable.fromStream(
    Stream.iterable([value + 1, value + 2, value + 3]),
    initialValue: 0,
  ),
).stream().listen((value) {
  print(value);
  // 0
  // 3
  // 4
  // 5
});
```

## Contributing

Reach out if there's any functionality you'd like added and happy coding!
