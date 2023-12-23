import 'package:computables/computables.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Computable', () {
    test("get", () {
      expect(Computable(2).get(), 2);
    });

    test("stream", () {
      final computable = Computable(2);

      expectLater(computable.stream(), emitsInOrder([2, 4, 4, 6]));

      computable.add(4);
      computable.add(4);
      computable.add(6);
    });

    test("streamChanges", () {
      final computable = Computable(2);

      expectLater(computable.streamChanges(), emitsInOrder([(2, 4), (4, 6)]));

      computable.add(4);
      computable.add(4);
      computable.add(6);
    });

    test('map', () {
      final computable = Computable(1);
      final computation = computable.map(
        (value) {
          return value + 1;
        },
      );

      computable.add(2);
      computable.add(3);

      expectLater(
        computation.stream(),
        emitsInOrder([2, 3, 4]),
      );
    });

    test('transform', () {
      final computation = Computable(1).transform(
        (value) {
          return Computable(value + 1);
        },
      );

      expectLater(
        computation.stream(),
        emits(2),
      );
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

    test('Includes duplicate values by default', () async {
      final computable = Computable(1);

      computable.add(2);
      computable.add(2);
      computable.add(3);

      expectLater(computable.stream(), emitsInOrder([1, 2, 2, 3]));
    });

    test('Dedupes duplicate values when specified', () async {
      final computable = Computable(1, dedupe: true);

      computable.add(2);
      computable.add(2);
      computable.add(3);

      expectLater(computable.stream(), emitsInOrder([1, 2, 3]));
    });
  });

  group('Computable value', () {
    test("Supports basic computation", () {
      final computable = Computable(2);

      expect(computable.get(), 2);

      expectLater(computable.stream(), emitsInOrder([2, 4, 6]));

      computable.add(4);
      computable.add(6);
    });
  });

  group('Computable iterable', () {
    test("Supports basic computation", () {
      final computable = Computable.fromIterable([1, 2, 3]);

      expect(computable.get(), 3);
      expectLater(computable.stream(), emitsInOrder([1, 2, 3]));
    });
  });

  group('Computable future', () {
    test("Supports basic computation", () {
      final computable =
          Computable.fromFuture(Future.value(2), initialValue: 0);
      expectLater(computable.stream(), emitsInOrder([0, 2]));
    });
  });

  group('Computable stream', () {
    test("Supports basic computation", () {
      final computable = Computable.fromStream(
        Stream.fromIterable([2, 4, 6]),
        initialValue: 0,
      );
      expectLater(computable.stream(), emitsInOrder([0, 2, 4, 6]));
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

  group(
    'Computations',
    () {
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

      test("Supports composability", () async {
        final computable1 = Computable(1);
        final computable2 = Computable(5);

        final stream = Computable.transform2(
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
        ).stream();

        expectLater(stream, emitsInOrder([0, 1, 2, 3, 4]));
      });

      test("Auto-disposes when all inputs are disposed", () async {
        final computable1 = Computable(1);
        final computable2 = Computable(2);

        final computation = Computable.compute2(
          computable1,
          computable2,
          (input1, input2) => input1 + input2,
        );

        computable1.dispose();
        await Future.delayed(const Duration(milliseconds: 1));
        expect(computation.isClosed, false);
        computable2.dispose();
        await Future.delayed(const Duration(milliseconds: 1));
        expect(computation.isClosed, true);
      });

      test(
          'Delivers recomputed values when synchronously accessed after an update',
          () {
        final computable1 = Computable(1);
        final computable2 = Computable(2);

        final computation = Computable.compute2(
          computable1,
          computable2,
          (input1, input2) => input1 + input2,
        );

        expect(computation.get(), 3);

        computable1.add(2);

        expect(computation.get(), 4);
      });
    },
  );

  group("Computation transforms", () {
    test('Subscribes to the output computable', () {
      final computable = Computable(1);
      final computable2 = Computable(2);

      final computation = Computable.transform2(
        computable,
        computable2,
        (input1, input2) {
          final fill = input2 - input1;
          return Computable.fromIterable(List.filled(fill, 0));
        },
      );

      expectLater(
        computation.stream(),
        emitsInOrder([0]),
      );
    });

    test(
        'Updates the output computable when an input computable emits an updated value.',
        () async {
      final computable = Computable(1);
      final computable2 = Computable(2);

      final computation = Computable.transform2(
        computable,
        computable2,
        (input1, input2) {
          return Computable(input1 + input2);
        },
      );

      computable2.add(5);

      expectLater(computation.stream(), emitsInOrder([3, 6]));
    });

    test(
        'Delivers recomputed values when synchronously accessed after an update',
        () {
      final computable = Computable(1);
      final computable2 = Computable(2);

      final computation = Computable.transform2(
        computable,
        computable2,
        (input1, input2) {
          return Computable(input1 + input2);
        },
      );

      expect(computation.get(), 3);

      computable2.add(5);

      expect(computation.get(), 6);
    });
  });
}
