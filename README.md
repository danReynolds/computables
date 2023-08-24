# Computables

Computables are composable, streamable values.

## Streamable

```dart
import 'package:computables/computables.dart';

Computable(2).stream().listen((value) {
  print(value);
  // 2
});

Computable.fromIterable([1,2,3]).stream().listen((value) {
  print(value);
  // 1
  // 2
  // 3
});

## Readable

```dart
final computable = Computable(2);
print(computable.get()) // 2
computable.add(3);
print(computable.get()) // 3
```

## Composable

```dart
final computation = Computable.compute2(
  Computable.fromStream(
    Stream.value(1),
    initialValue: 0,
  ),
  Computable.fromFuture(
    Future.value(2),
    initialValue: 0,
  ),
  (input1, input2) => input1 + input2,
);

computation.stream().listen((value) {
  print(value);
  // 0
  // 1
  // 3
});
```

## Composable Composable

```dart
final computation = Computable.compute2(
  Computable.fromStream(
    Stream.value(1),
    initialValue: 0,
  ),
  Computable.fromFuture(
    Future.value(2),
    initialValue: 0,
  ),
  (input1, input2) => input1 + input2,
);

Computable.compute2(
  computation,
  Computable(1),
).stream().listen((value) {
  print(value);
  // 1
  // 2
  // 4
});
```

## Forwardable

```dart
final computable = Computable.subscriber(initialValue: 0);
final stream = Stream.fromIterable([1, 2, 3]);
computable.forwardStream(stream);

computable.stream().listen((value) {
  print(value);
  // 0
  // 1
  // 2
  // 3
})
```

## Enjoyable?

Reach out if there's any functionality you'd like added and happy coding!