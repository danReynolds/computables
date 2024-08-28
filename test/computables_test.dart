import 'dart:async';

import 'package:computables/computables.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Computable', () {
    test("get", () {
      expect(Computable(2).get(), 2);
    });

    group("stream", () {
      test('Emits values on the stream', () {
        final computable = Computable(2);

        expectLater(computable.stream(), emitsInOrder([2, 4, 6]));

        computable.add(4);
        computable.add(6);
      });

      test(
        'Is a non-broadcast stream by default',
        () {
          final computable = Computable(2);
          expect(computable.stream().isBroadcast, false);
        },
      );

      test(
        'Is a broadcast stream when specified',
        () {
          final computable = Computable(2, broadcast: true);
          expect(computable.stream().isBroadcast, true);
        },
      );
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

    test("ignores duplicates by default", () {
      final computable = Computable(1);

      expectLater(
        computable.stream(),
        emitsInOrder([1, 2, 3]),
      );

      computable.add(2);
      computable.add(2);
      computable.add(3);
    });

    test("re-emits duplicates when specified", () {
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
      test('compute multiple inputs', () async {
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

      test('does not broadcast intermediate values from the same task',
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

      test('recomputes immediately if accessed synchronously', () {
        final computable = Computable(1);

        final computation = computable.map((value) => value + 1);

        expect(computation.get(), 2);

        computable.add(5);

        // The update to the computation's dependency computable is scheduled to be processed
        // asynchronously, however, since its value has been accessed synchronously, it should
        // recompute immediately.
        expect(computation.get(), 6);
      });

      test("cancels non-broadcast computables automatically", () async {
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

      test("does not cancel broadcast computables automatically", () async {
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

      test('immediately returns updated values', () {
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
    test('emits values from the inner computable', () async {
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

    test('immediately returns updated values', () {
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

    test('returns updated values from a dirty inner computable', () {
      final computable = Computable(1);
      final computable2 = Computable(2);

      final computation = computable.transform(
        (input1) {
          return computable2.map((input2) => input1 + input2);
        },
      );

      expect(computation.get(), 3);

      computable2.add(5);

      expect(computation.get(), 6);
    });
  });

  group('Subscriber', () {
    test('forwards computable', () async {
      final subscriber = Computable.subscriber(0);

      subscriber.forward(Computable(1));

      expect(subscriber.get(), 1);
    });

    test('subscribes to computable', () async {
      int result = 0;
      final subscriber = Computable.subscriber(0);

      subscriber.subscribe(Computable(1), (val) {
        result = val;
      });

      expect(result, 1);
    });

    test('forwards stream', () {
      final subscriber = Computable.subscriber(0);

      subscriber.forwardStream(Stream.value(1));

      expectLater(
        subscriber.stream(),
        emitsInOrder([0, 1]),
      );
    });

    test('forwards future', () {
      final subscriber = Computable.subscriber(0);

      subscriber.forwardFuture(Future.value(1));

      expectLater(
        subscriber.stream(),
        emitsInOrder([0, 1]),
      );
    });
  });
}
