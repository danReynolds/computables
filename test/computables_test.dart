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

      test('Detects and ignores cyclical dependencies', () {
        String? cyclicalPrint;

        runZoned(
          () {
            final computable1 = Computable(1, broadcast: true);
            final computable2 = Computable(2, broadcast: true);

            Computation<int>? computation1;
            Computation<int>? computation2;

            computation1 = Computation.compute(
              () {
                if (computable1.get() == 3) {
                  return computation2!.get() + 1;
                }
                return computable1.get() + computable2.get();
              },
              broadcast: true,
            );

            computation2 = Computation.compute(
              () {
                if (computable1.get() == 3) {
                  return computation1!.get() + 1;
                }
                return computable1.get() - computable2.get();
              },
              broadcast: true,
            );

            // When computable1 is updated, both computation1 and computation2 react to the change.
            // computation1 recomputes first (since it listened to computable1 first), marking computation2 as a dependency and broadcasts to listeners (noone yet).
            //
            // computation2 then recomputes, marking computation1 as a dependency and broadcasts to listeners (computation1).
            //
            // computation1 starts to recompute in response to its dependency, computation2 rebroadcasting. However, the current computation
            // context is marked as computation2, so computation1 observes that one if its dependencies, computation2 triggered its own recomputation
            // and reports that a cycle occurred, canceling recalculation.
            computable1.add(3);

            computable1.dispose();
            computable2.dispose();
            computation1.dispose();
            computation2.dispose();
          },
          zoneSpecification: ZoneSpecification(
            // Intercept print calls
            print: (_, __, ___, line) {
              cyclicalPrint = line;
            },
          ),
        );

        expect(
          cyclicalPrint,
          "Cyclical dependency Instance of 'Computation<int>' detected during recomputation of: Instance of 'Computation<int>'",
        );
      });
    },
  );

  group("Computation transforms", () {
    test('Emits values from the inner computable', () async {
      final computable = Computable(1);
      final computable2 = Computable(2);

      final computation = ComputationTransform(
        () {
          final value = computable2.get() - computable.get();
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

      final computation = ComputationTransform(
        () {
          final value = computable2.get() - computable.get();
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

      final computation = ComputationTransform(
        () {
          return Computable(computable.get() + computable2.get());
        },
      );

      expect(computation.get(), 3);

      computable2.add(5);

      expect(computation.get(), 6);
    });

    test('Detects and ignores cyclical dependencies', () {
      String? cyclicalPrint;

      runZoned(
        () {
          final computable1 = Computable(1, broadcast: true);
          final computable2 = Computable(2, broadcast: true);

          ComputationTransform<int>? transform1;
          ComputationTransform<int>? transform2;

          transform1 = Computation.transform(
            () {
              if (computable1.get() == 3) {
                return Computable(transform2!.get() + 1);
              }
              return Computable(computable1.get() + computable2.get());
            },
            broadcast: true,
          );

          transform2 = Computation.transform(
            () {
              if (computable1.get() == 3) {
                return Computable(transform1!.get() + 1);
              }
              return Computable(computable1.get() - computable2.get());
            },
            broadcast: true,
          );

          // When computable1 is updated, both transform1 and transform2's inner computations recompute and trigger resubscriptions to their updated
          // inner computations.
          //
          // transform1's inner computation recomputes first (since it subscribed to computable1 first), marking transform2 as a dependency and then
          // broadcasts to its only dependent, transform1. transform1 resubscribes to the new computable from its inner computation and broadcasts to dependents (currently noone).
          //
          // transform2's inner computation then recomputes, marking transform1 as a dependency and then broadcasts to its only dependent, transform2.
          // transform2 resubscribes to the new computable from its inner computation and broadcasts to its dependents, which includes transform1's inner computable.
          //
          // transform1's inner computable goes to recompute, however transform2 marked itself as the current computable context in its resubscription ahead of broadcasting to its dependents
          // so transform1's inner computable observes that one of its dependents, transform2, has triggered its recomputation and reports a cyclical dependency, aborting recomputation.
          computable1.add(3);

          computable1.dispose();
          computable2.dispose();
          transform1.dispose();
          transform2.dispose();
        },
        zoneSpecification: ZoneSpecification(
          // Intercept print calls
          print: (_, __, ___, line) {
            cyclicalPrint = line;
          },
        ),
      );

      expect(
        cyclicalPrint,
        "Cyclical dependency Instance of 'ComputationTransform<int>' detected during recomputation of: Instance of 'Computation<Computable<int>>'",
      );
    });
  });
}
