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

    test('map', () {
      final computable = Computable(1);
      final computation = computable.map(
        (value) {
          return value + 1;
        },
      );

      expectLater(
        computation.stream(),
        emitsInOrder([2, 3, 4]),
      );

      computable.add(2);
      computable.add(3);
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

    test("Non-broadcast computable does not buffer values", () {
      final computable = Computable(2);
      computable.add(3);

      expectLater(computable.stream(), emitsInOrder([3]));
    });

    test("Broadcast computable does not buffer values", () {
      final computable = Computable(2, broadcast: true);
      computable.add(3);

      expectLater(computable.stream(), emitsInOrder([3, emitsDone]));
      computable.dispose();
    });

    test("emits an initial null", () {
      final computable = Computable(null);
      expectLater(computable.stream(), emitsInOrder([null]));
    });

    test('Includes duplicate values by default', () async {
      final computable = Computable(1);

      expectLater(computable.stream(), emitsInOrder([1, 2, 2, 3]));

      computable.add(2);
      computable.add(2);
      computable.add(3);
    });

    test('Dedupes duplicate values when specified', () async {
      final computable = Computable(1, dedupe: true);

      expectLater(computable.stream(), emitsInOrder([1, 2, 3]));

      computable.add(2);
      computable.add(2);
      computable.add(3);
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

  group('Computable future', () {
    test("Supports basic computation", () {
      final computable = Computable.fromFuture(
        Future.value(2),
        initialValue: 0,
      );
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

      test("Transforms multiple inputs", () async {
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
        expect(computation.isClosed, false);
        computable2.dispose();
        expect(computation.isClosed, true);
      });

      test("Cancels subscriptions when disposed", () async {
        final computable1 = Computable(1);
        final computable2 = Computable(2);

        final computation = Computable.compute2(
          computable1,
          computable2,
          (input1, input2) => input1 + input2,
        );

        computation.dispose();

        expect(computable1.isClosed, true);
        expect(computable2.isClosed, true);
      });

      test('Immediately returns updated values', () {
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
    test('Emits values from the inner computable', () {
      final computable = Computable(1);
      final computable2 = Computable(2);

      final computation = Computable.transform2(
        computable,
        computable2,
        (input1, input2) {
          return Computable(input2 - input1);
        },
      );

      expectLater(
        computation.stream(),
        emitsInOrder([1]),
      );
    });

    test('Emits values from the latest inner computable', () async {
      final computable = Computable(1);
      final computable2 = Computable(2);

      final computation = Computable.transform2(
        computable,
        computable2,
        (input1, input2) {
          return Computable(input1 + input2);
        },
      );

      expectLater(computation.stream(), emitsInOrder([3, 6]));

      computable2.add(5);
    });

    test('Immediately returns updated values', () {
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
