import 'dart:async';

import 'package:computables/computables.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Computable', () {
    test("get", () {
      expect(Computable(2).get(), 2);
    });

    test("stream", () {
      final computable = Computable(2);

      expectLater(computable.stream(), emitsInOrder([2, 4, 6]));

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

    test("emits an initial null", () {
      final computable = Computable(null);
      expectLater(computable.stream(), emitsInOrder([null]));
    });

    test("Ignores duplicates", () {
      final computable = Computable(1);

      expectLater(
        computable.stream(),
        emitsInOrder([1, 2, 3]),
      );

      computable.add(2);
      computable.add(2);
      computable.add(3);
    });
  });

  group(
    'Computations',
    () {
      test('Compute multiple inputs', () {
        final computation = Computable.compute2(
          Computable.fromFuture(
            Future.value(1),
            initialValue: 0,
          ),
          Computable.fromStream(
            Stream.value(2),
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

      test("Cancels non-broadcast computables automatically", () async {
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

      test("Does not cancel broadcast computables automatically", () async {
        final computable1 = Computable(1, broadcast: true);
        final computable2 = Computable(2);

        final computation = Computable.compute2(
          computable1,
          computable2,
          (input1, input2) => input1 + input2,
        );

        computation.dispose();

        expect(computable1.isClosed, false);
        expect(computable2.isClosed, true);

        computable1.dispose();
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

  group("Transforms", () {
    test('Emits values from the inner computable', () async {
      final computable = Computable(1);
      final computable2 = Computable(2);

      final computation = Computable.transform2(
        computable,
        computable2,
        (input1, input2) {
          final value = input2 - input1;
          return Computable.fromStream(
            Stream.fromIterable([value, value + 1, value + 2]),
            initialValue: 0,
          );
        },
        broadcast: true,
      );

      final result1 = await computation.stream().take(4).toList();

      expect(result1, [0, 1, 2, 3]);

      computable2.add(5);

      final result2 = await computation.stream().take(4).toList();
      expect(result2, [0, 4, 5, 6]);

      computation.dispose();
    });

    test('Cancels the previous inner computable', () async {
      final computable = Computable(1);
      final computable2 = Computable(2);

      final computation = Computable.transform2(
        computable,
        computable2,
        (input1, input2) {
          final value = input2 - input1;
          return Computable.fromStream(
            Stream.fromIterable([value, value + 1, value + 2]),
            initialValue: 0,
          );
        },
        broadcast: true,
      );

      final result1 = await computation.stream().take(2).toList();

      expect(result1, [0, 1]);

      // When computable2 is updated, the transform's subscribes to the new inner computable and works like a switchMap,
      // unsubscribing from the previous computable value and never emits the rest of the values (2,3) that its stream was going to emit.
      computable2.add(5);

      final result2 = await computation.stream().take(4).toList();
      expect(result2, [0, 4, 5, 6]);

      computation.dispose();
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

  group('Subscriber', () {
    test('Forwards computable', () async {
      final subscriber = Computable.subscriber(0);

      subscriber.forward(Computable(1));

      expect(subscriber.get(), 1);
    });

    test('Subscribes to computable', () async {
      int result = 0;
      final subscriber = Computable.subscriber(0);

      subscriber.subscribe(Computable(1), (val) {
        result = val;
      });

      expect(result, 1);
    });

    test('Forwards stream', () {
      final subscriber = Computable.subscriber(0);

      subscriber.forwardStream(Stream.value(1));

      expectLater(
        subscriber.stream(),
        emitsInOrder([0, 1]),
      );
    });

    test('Forwards future', () {
      final subscriber = Computable.subscriber(0);

      subscriber.forwardFuture(Future.value(1));

      expectLater(
        subscriber.stream(),
        emitsInOrder([0, 1]),
      );
    });
  });
}
