# Computables

Computables are composable, streamable values.

## Streamable

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

## Readable

```dart
final computable = Computable(2);
print(computable.get()) // 2
computable.add(3);
print(computable.get()) // 3
```

## Composable

```dart
final computable = Computable.compute2(
  Computable.fromStream(
    Stream.value(1),
    initialValue: 0,
  ),
  Computable.fromFuture(
    Future.value(2),
    initialValue: 0,
  ),
  (input1, input2) => input1 + input2,
  broadcast: true,
);

computable.stream().listen((value) {
  print(value);
  // 0
  // 1
  // 3
});

Computable.compute2(
  computable,
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
final computable2 = Computable(5);

Computable.transform2(
  computable1,
  computable2,
  (input1, input2) {
    return Computable.fromStream(
      Stream.fromIterable(
        List.generate(input2 - input1, (diff) => diff + 1),
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

## Mappable

```dart
final computable = Computable(2);

computable.map((value) => value + 1).stream().listen((value) {
  print(value);
  // 3
  // 4
});

computable.add(3);
```

## Enjoyable?

Reach out if there's any functionality you'd like added and happy coding!
