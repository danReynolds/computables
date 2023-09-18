import 'package:computables/computables.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Computable value', () {
    test("Supports basic computation", () {
      final computable = Computable(2);

      expect(computable.get(), 2);

      expectLater(computable.stream(), emitsInOrder([2, 4, 6]));

      computable.add(4);
      computable.add(6);
    });

    test("non-broadcast computable buffers values", () {
      // Non-broadcast stream controllers buffer events until they have a listener.
      final computable = Computable(2);
      computable.add(3);
      expectLater(computable.stream(), emitsInOrder([2, 3]));
    });

    test("broadcast computable emits the latest value", () {
      // Broadcast stream controllers do not buffer events even when there is no listener.
      // Instead, for broadcast computables, we deliver the latest value of the computable whenever
      // a listener subscribes.
      final computable = Computable(2, broadcast: true);
      computable.add(3);
      computable.add(4);

      expectLater(computable.stream(), emitsInOrder([4, emitsDone]));
      computable.dispose();
    });

    test("emits an initial null", () {
      final computable = Computable(null);
      expectLater(computable.stream(), emitsInOrder([null]));
    });
  });

  group('Computable iterable', () {
    test("Supports basic computation", () {
      final computable = Computable.fromIterable([1, 2, 3]);

      expect(computable.get(), 3);
      expectLater(computable.stream(), emitsInOrder([1, 2, 3]));
    });
  });

  group('Computable Future', () {
    test("Supports basic computation", () {
      final computable =
          Computable.fromFuture(Future.value(2), initialValue: 0);
      expectLater(computable.stream(), emitsInOrder([0, 2]));
    });
  });

  group('Computable Stream', () {
    test("Supports basic computation", () {
      final computable = Computable.fromStream(
        Stream.fromIterable([2, 4, 6]),
        initialValue: 0,
      );
      expectLater(computable.stream(), emitsInOrder([0, 2, 4, 6]));
    });
  });

  group('Computations', () {
    test('Computes multiple inputs', () {
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

      expect(computation.get(), 0);

      expectLater(
        computation.stream(),
        emitsInOrder([0, 1, 3]),
      );
    });

    test("Supports composabiltiy", () {
      final computation = Computable.compute2<double, double, double>(
        Computable.fromStream<double>(
          Stream.value(1),
          initialValue: 0,
        ),
        Computable.fromFuture<double>(
          Future.value(2),
          initialValue: 0,
        ),
        (input1, input2) => input1 + input2,
      );

      final computation2 = Computable.compute2<double, double, double>(
        computation,
        Computable(1),
        (input1, input2) => input1 + input2,
      );

      expectLater(computation2.stream(), emitsInOrder([1, 2, 4]));
    });
  });

  group('Computable subscriber', () {
    test('Supports forwarding streams', () {
      final computable = Computable.subscriber(initialValue: 0);
      final stream = Stream.fromIterable([1, 2, 3]);

      computable.forwardStream(stream);
      expectLater(computable.stream(), emitsInOrder([0, 1, 2, 3]));
    });

    test('Supports subscribing to streams', () {
      final computable = Computable.subscriber(initialValue: 0);
      final stream = Stream.fromIterable([1, 2, 3]);

      computable.subscribeStream(stream, (value) {
        computable.add(value + 1);
      });

      expectLater(computable.stream(), emitsInOrder([0, 2, 3, 4]));
    });

    test('Supports forwarding futures', () {
      final computable = Computable.subscriber(initialValue: 0);
      final future = Future.value(2);

      computable.forwardFuture(future);
      expectLater(computable.stream(), emitsInOrder([0, 2]));
    });

    test('Supports subscribing to futures', () {
      final computable = Computable.subscriber(initialValue: 0);
      final future = Future.value(2);

      computable.subscribeFuture(future, (value) {
        computable.add(value + 1);
      });

      expectLater(computable.stream(), emitsInOrder([0, 3]));
    });
  });

  group('streamChanges', () {
    test("Streams value changes", () {
      final computable = Computable(2);

      expectLater(computable.streamChanges(), emitsInOrder([(2, 4), (4, 6)]));

      computable.add(4);
      computable.add(4);
      computable.add(6);
    });
  });
}
