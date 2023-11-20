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

```

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
  (input1, input2) => input1 + input2,
).stream().listen((value) {
  print(value);
  // 1
  // 2
  // 4
});
```

## Transformable

```dart
final computable1 = Computable(1);
final computable2 = Computable(2);

final outputComputable = Computable.transform2(
  computable1,
  computable2,
  (input1, input2) {
    final fill = input2 - input1;
    return Computable.fromIterable(
      List.filled(fill, 0)
    );
  },
).stream().listen((value) {
  print('Value: $value');
});
// Value: 0

computable2.add(5);

// Value: 0
// Value: 0
// Value: 0
// Value: 0
```

## Enjoyable?

Reach out if there's any functionality you'd like added and happy coding!
