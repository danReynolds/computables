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

    test('map', () async {
      final computable = Computable(1);
      final computation = computable.map(
        (value) {
          return value + 1;
        },
      );

      expectLater(
        computation.stream(),
        emitsInOrder([2, 4, 5]),
      );

      // Ignores intermediate values.
      computable.add(2);

      computable.add(3);

      await Future.delayed(const Duration(milliseconds: 1));

      computable.add(4);
    });

    test('transform', () async {
      final computable = Computable(1);

      final computation = computable.transform(
        (value) {
          return Computable(value + 1);
        },
      );

      expectLater(computation.stream(), emitsInOrder([2, 4]));

      await Future.delayed(const Duration(milliseconds: 1));

      // Ignores intermediate values.
      computable.add(2);

      computable.add(3);
    });

    test("emits an initial null", () {
      final computable = Computable(null);
      expectLater(computable.stream(), emitsInOrder([null]));
    });

    test("Ignores duplicates by default", () {
      final computable = Computable(1);

      expectLater(
        computable.stream(),
        emitsInOrder([1, 2, 3]),
      );

      computable.add(2);
      computable.add(2);
      computable.add(3);
    });

    test("Re-emits duplicates when specified", () {
      final computable = Computable(1, dedupe: false);

      expectLater(
        computable.stream(),
        emitsInOrder([1, 2, 2, 3]),
      );

      computable.add(2);
      computable.add(2);
      computable.add(3);
    });
  });

  group(
    'Computations',
    () {
      test('Computes multiple inputs', () async {
        final computable1 = Computable(0);
        final computable2 = Computable(0);

        final computation = Computable.compute2(
          computable1,
          computable2,
          (input1, input2) => input1 + input2,
        );

        expect(computation.get(), 0);

        final future = computation.stream().take(4).toList();

        computable1.add(1);
        expect(computation.get(), 1);

        await Future.delayed(const Duration(milliseconds: 1));

        computable1.add(2);
        expect(computation.get(), 2);

        await Future.delayed(const Duration(milliseconds: 1));

        computable2.add(2);
        expect(computation.get(), 4);

        expect(
          await future,
          [0, 1, 2, 4],
        );
      });

      test('Does not broadcast intermediate values from the same task',
          () async {
        final computable1 = Computable(0);
        final computable2 = Computable(0);

        final computation = Computable.compute2(
          computable1,
          computable2,
          (input1, input2) => input1 + input2,
        );

        final future = computation.stream().take(2).toList();

        expect(computation.get(), 0);

        // This intermediate update in the same task is not broadcast by the computation.
        computable1.add(1);
        computable1.add(2);

        expect(await future, [0, 2]);
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
          return Computable(input2 - input1);
        },
      );

      expect(computation.get(), 1);

      final future = computation.stream().take(2).toList();

      computable2.add(5);

      expect(computation.get(), 4);

      expect(await future, [1, 4]);
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
            Stream.fromIterable([
              value, // 1
              value + 1, // 2
              value + 2, // 3
              value + 3, // 4
              value + 4, // 5
            ]),
            initialValue: 0,
          );
        },
        broadcast: true,
      );

      final result1 = await computation.stream().take(2).toList();

      expect(result1, [0, 1]);

      // When computable2 is updated, the transform subscribes to the new inner computable and works like a switchMap,
      // unsubscribing from the previous computable value and never emitting the rest of the values (3, 4, 5) that its stream was going to emit.
      computable2.add(10);

      final result2 = await computation.stream().take(4).toList();

      // 2 is still emitted since it was already scheduled asynchronously.
      expect(result2, [2, 0, 9, 10]);

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
