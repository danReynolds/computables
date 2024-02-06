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
        final futureComputable = Computable.fromFuture(
          Future.value(1),
          initialValue: 0,
        );
        final streamComputable = Computable.fromStream(
          Stream.value(2),
          initialValue: 0,
        );

        final computation = Computation(
          () => futureComputable.get() + streamComputable.get(),
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

        final stream = ComputationTransform(
          () {
            return Computable.fromStream(
              Stream.fromIterable(
                List.generate(
                  computable2.get() - computable1.get(),
                  (index) => index + 1,
                ),
              ),
              initialValue: 0,
            );
          },
        ).stream();

        expectLater(stream, emitsInOrder([0, 1, 2, 3, 4]));
      });

      test("Cancels non-broadcast computables automatically", () async {
        final computable1 = Computable(1);
        final computable2 = Computable(2);

        final computation = Computation(
          () => computable1.get() + computable2.get(),
        );

        computation.dispose();

        expect(computable1.isClosed, true);
        expect(computable2.isClosed, true);
      });

      test("Does not cancel broadcast computables automatically", () async {
        final computable1 = Computable(1, broadcast: true);
        final computable2 = Computable(2);

        final computation = Computation(
          () => computable1.get() + computable2.get(),
        );

        computation.dispose();

        expect(computable1.isClosed, false);
        expect(computable2.isClosed, true);

        computable1.dispose();
      });

      test('Immediately returns updated values', () {
        final computable1 = Computable(1);
        final computable2 = Computable(2);

        final computation = Computation(
          () => computable1.get() + computable2.get(),
        );

        expect(computation.get(), 3);
        computable1.add(2);
        expect(computation.get(), 4);
      });

      test('Unsubscribes to stale dependencies', () async {
        final computable1 = Computable(0);
        final computable2 = Computable(10);

        final computation = Computation(
          () {
            final value1 = computable1.get();

            if (value1 >= 1) {
              return value1;
            }

            return computable2.get();
          },
        );

        final future = computation.stream().take(3).toList();

        computable1.add(1);

        // The subsequent update to computable2 is ignored since it was removed
        // from the computation's dependencies
        computable2.add(4);

        computable1.add(2);

        final result = await future;

        expect(result, [10, 1, 2]);
      });
    },
  );

  group("Computation transforms", () {
    test('Emits values from the inner computable', () {
      final computable = Computable(1);
      final computable2 = Computable(2);

      final computation = ComputationTransform(
        () {
          return Computable(computable2.get() - computable.get());
        },
      );

      expectLater(
        computation.stream(),
        emitsInOrder([1, 4]),
      );

      computable2.add(5);
    });

    test('Immediately returns updated values', () {
      final computable = Computable(1);
      final computable2 = Computable(2);

      final computation = ComputationTransform(
        () {
          return Computable(computable.get() + computable2.get());
        },
      );

      expect(computation.get(), 3);

      computable2.add(5);

      expect(computation.get(), 6);
    });
  });
}
