import 'dart:async';
import 'package:computables/computables.dart';
import 'package:test/test.dart';
import 'utils.dart';

void main() {
  group('Computable', () {
    test("get", () {
      expect(Computable(2).get(), 2);
    });

    test('add', () {
      final computable = Computable(2);

      expect(computable.get(), 2);
      computable.add(3);
      expect(computable.get(), 3);
    });

    group("stream", () {
      test('emits values on the stream', () {
        final computable = Computable(2);

        // Computables batch updates within the current task of the event loop.
        // 4 is an intermediate value in the current task and is not emitted.
        expectLater(computable.stream(), emitsInOrder([2, 4]));

        computable.add(4);
      });

      test('does not emit intermediate values on the stream', () {
        final computable = Computable(2);

        // Computables batch updates within the current task of the event loop.
        // 4 is an intermediate value in the current task and is not emitted.
        expectLater(computable.stream(), emitsInOrder([2, 6]));

        computable.add(4);
        computable.add(6);
      });

      test('is closed on dispose', () async {
        final computable = Computable(2);

        expectLater(computable.stream(), emitsInOrder([2, 4, 6, emitsDone]));

        computable.add(4);
        await pause();
        computable.add(6);
        await pause();

        computable.dispose();
      });

      test('supports multiple listeners', () async {
        final computable = Computable(2);

        final stream = computable.stream();
        expectLater(stream, emitsInOrder([2, 4, 6, emitsDone]));
        expectLater(stream, emitsInOrder([2, 4, 6, emitsDone]));

        computable.add(4);
        await pause();
        computable.add(6);
        await pause();

        computable.dispose();
      });
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

      await pause();

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

      // Does not emit intermediate values.
      computable.add(2);
      computable.add(3);
    });

    test("emits an initial null", () {
      final computable = Computable(null);
      expectLater(computable.stream(), emitsInOrder([null]));
    });

    test("ignores duplicates by default", () async {
      final computable = Computable(1);

      expectLater(
        computable.stream(),
        emitsInOrder([1, 2, 3]),
      );

      computable.add(2);
      await pause();
      computable.add(2);
      await pause();
      computable.add(3);
    });

    test("re-emits duplicates when specified", () async {
      final computable = Computable(1, dedupe: false);

      expectLater(
        computable.stream(),
        emitsInOrder([1, 2, 2, 3]),
      );

      computable.add(2);
      await pause();
      computable.add(2);
      await pause();
      computable.add(3);
    });
  });
  group(
    'Computation',
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
        expectLater(computation.stream(), emitsInOrder([0, 1, 2, 4]));

        computable1.add(1);
        expect(computation.get(), 1);

        await pause();

        computable1.add(2);
        expect(computation.get(), 2);

        await pause();

        computable2.add(2);
        expect(computation.get(), 4);
      });

      test(
        'Does not broadcast intermediate values',
        () async {
          final computable1 = Computable(0);
          final computable2 = Computable(0);

          final computation = Computable.compute2(
            computable1,
            computable2,
            (input1, input2) => input1 + input2,
          );

          expect(computation.get(), 0);
          expectLater(computation.stream(), emitsInOrder([0, 2]));

          // This intermediate update in the same task is not broadcast by the computation.
          computable1.add(1);
          computable1.add(2);
        },
      );

      test('Recomputes immediately if accessed synchronously', () {
        final computable = Computable(1);

        final computation = computable.map((value) => value + 1);

        expect(computation.get(), 2);

        computable.add(5);

        // The update to the computation's dependency computable is scheduled to be processed
        // asynchronously, however, since its value has been accessed synchronously, it should
        // recompute immediately.
        expect(computation.get(), 6);
      });

      test('Does not automatically recompute when inactive', () async {
        final computable1 = Computable(1);
        final computable2 = Computable(2);

        final List<num> values = [];

        final computation = Computable.compute2(
          computable1,
          computable2,
          (input1, input2) => (values..add(input1 + input2)).last,
        );

        await pause();

        expect(values.length, 0);
        expect(computation.get(), 3);
        expect(values.length, 1);

        computable1.add(2);

        await pause();

        expect(values.length, 1);
        expect(computation.get(), 4);
        expect(values.length, 2);
      });

      test('Does automatically recompute when active', () async {
        final computable1 = Computable(1);
        final computable2 = Computable(2);

        final List<num> values = [];

        final computation = Computable.compute2(
          computable1,
          computable2,
          (input1, input2) => (values..add(input1 + input2)).last,
        );

        computation.stream().listen(null);

        expect(values.length, 1);

        computable1.add(2);

        await pause();

        expect(values.length, 2);
      });

      test(
        'Dynamically activates based on active listeners and active dependencies',
        () async {
          final computable1 = Computable(1);
          final computable2 = Computable(2);

          final List<num> values = [];

          final computation = Computable.compute2(
            computable1,
            computable2,
            (input1, input2) => (values..add(input1 + input2)).last,
          );

          expect(computation.isActive, false);

          // The computation is now active, as it has a stream listener.
          final subscription = computation.stream().listen(null);

          expect(computation.isActive, true);
          expect(values.length, 1);

          computable1.add(2);

          await pause();

          expect(values.length, 2);

          subscription.cancel();

          // Now that the listener to the computable's stream has been canceled, the computation is no
          // longer active and has stopped receiving automatic updates from its dependencies.
          expect(computation.isActive, false);

          computable1.add(3);

          await pause();

          expect(values.length, 2);
          expect(computation.get(), 5);
          expect(values.length, 3);

          final downstreamComputation = computation.map((value) => value + 1);

          expect(computation.isActive, false);

          final downstreamSubscription =
              downstreamComputation.stream().listen(null);

          // Now that a computable downstream of this computation has a stream listener
          // this computation is also active again.
          expect(computation.isActive, true);

          computable1.add(4);

          await pause();

          expect(values.length, 4);
          expect(computation.get(), 6);
          expect(values.length, 4);

          downstreamSubscription.cancel();

          // Once the downstream computation is canceled, this computable is again now inactive.
          expect(computation.isActive, false);

          computable1.add(5);

          await pause();

          expect(values.length, 4);
          expect(computation.get(), 7);
          expect(values.length, 5);
        },
      );

      test(
        'Removes active dependencies when they are disposed',
        () {
          final computable1 = Computable(1);
          final computable2 = Computable(2);

          final computation = Computable.compute2(
            computable1,
            computable2,
            (input1, input2) => input1 + input2,
          ) as Dependent;

          computation.stream().listen(null);

          // The computation has two dependencies: computable1 and computable2.
          expect(computation.dependenciesLength, 2);
          expect(computation.isClosed, false);

          computable1.add(2);

          expect(computation.get(), 4);

          // The computation should remove its dependency on computable1 when it is disposed.
          computable1.dispose();

          expect(computation.dependenciesLength, 1);
        },
      );

      test(
        'Caches null values',
        () {
          final computable1 = Computable<num?>(null);
          final computable2 = Computable(2);

          final List<num> values = [];

          final computation = Computable.compute2(
            computable1,
            computable2,
            (input1, input2) => (values..add((input1 ?? 0) + input2)).last,
          );

          computation.stream().listen(null);

          expect(values.length, 1);

          computable2.add(3);

          expect(computation.get(), 3);
          expect(values.length, 2);

          expect(computation.get(), 3);

          // The computation should have cached the values for its input computables, even when null.
          // It therefore should not have recomputed after re-accessing its value.
          expect(values.length, 2);
        },
      );

      test(
        'Clears the resolver cache if an exception is thrown during resolution',
        () {
          final computable1 = Computable(1);
          final computable2 = Computable(2);

          final computation = Computable.compute2(
            computable1,
            computable2,
            (input1, input2) {
              if (input1 == 1) {
                throw Exception('Test exception');
              }
              return input1 + input2;
            },
          );

          try {
            computation.get();
          } catch (e) {
            computable1.add(2);
            expect(computation.get(), 4);
          }
        },
      );
    },
  );

  group("Computation transform", () {
    test('emits values from the inner computable', () async {
      final computable = Computable(1);
      final computable2 = Computable(2);

      final transform = Computable.transform2(
        computable,
        computable2,
        (input1, input2) {
          return Computable(input2 - input1);
        },
      );

      expectLater(transform.stream(), emitsInOrder([1, 4]));

      computable2.add(5);
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

    test('Recomputes when values are added to the inner computable', () {
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

    test('Does not automatically recompute when inactive', () async {
      final computable = Computable(1);
      final computable2 = Computable(2);

      final List<num> values = [];

      final computation = computable.transform(
        (input1) {
          return computable2.map((input2) => input1 + input2);
        },
      );
      final downstreamComputation = computation.map(
        (value) => (values..add(value)).last,
      );

      expect(computation.isActive, false);
      expect(downstreamComputation.isActive, false);

      await pause();

      expect(values.length, 0);
      expect(downstreamComputation.get(), 3);
      expect(values.length, 1);

      computable2.add(5);

      await pause();

      expect(values.length, 1);
      expect(downstreamComputation.get(), 6);
      expect(values.length, 2);
    });

    test('Does automatically recompute when active', () async {
      final computable = Computable(1);
      final computable2 = Computable(2);

      final List<num> values = [];

      final computation = computable.transform(
        (input1) {
          return computable2.map((input2) => input1 + input2);
        },
      );
      final downstreamComputation = computation.map(
        (value) => (values..add(value)).last,
      );

      expect(computation.isActive, false);
      expect(downstreamComputation.isActive, false);

      final subscription = downstreamComputation.stream().listen(null);

      expect(computation.isActive, true);
      expect(downstreamComputation.isActive, true);

      await pause();

      expect(values.length, 1);
      expect(downstreamComputation.get(), 3);
      expect(values.length, 1);

      computable2.add(5);

      await pause();

      expect(values.length, 2);
      expect(downstreamComputation.get(), 6);
      expect(values.length, 2);

      subscription.cancel();

      expect(downstreamComputation.isActive, false);
      expect(computation.isActive, false);

      computable2.add(6);

      await pause();

      expect(values.length, 2);
      expect(downstreamComputation.get(), 7);
      expect(values.length, 3);
    });

    test(
      'Maintains the correct dependency count when the inner computable emits new values',
      () {
        final computable = Computable(1);
        final computable2 = Computable(2);
        final computable3 = Computable(0);

        final computation = Computable.transform2(
          computable,
          computable2,
          (input1, input2) {
            computable3.add(input1 + input2);
            return computable3;
          },
        ) as Dependent;

        // The computation transform has two dependencies: the inner computation made up of computable and computable2 as well
        // as its output computable, computable3.
        expect(computation.get(), 3);
        expect(computation.dependenciesLength, 2);
        expect(computation.isClosed, false);

        computable.add(2);

        expect(computation.get(), 4);

        // The transform's dependency count should remain the same when its inner computable emits a new value. It should remain
        // dependent on the inner computation and have replaced its old dependency on the inner computation's previous output computable with the new one.
        expect(computation.dependenciesLength, 2);
      },
    );
  });

  group('Forwarder', () {
    test('forwards computable', () async {
      final forwarder = Computable.forwarder(0);

      expectLater(forwarder.stream(), emitsInOrder([0, 1]));

      forwarder.forward(Computable(1));
      expect(forwarder.get(), 1);
    });

    test('forwards computation', () async {
      final forwarder = Computable.forwarder(0);

      expectLater(forwarder.stream(), emitsInOrder([0, 4]));

      final computable1 = Computable(1);
      final computable2 = Computable(2);
      final computation = Computable.compute2(
        computable1,
        computable2,
        (value1, value2) => value1 + value2,
      );

      forwarder.forward(computation);
      expect(forwarder.get(), 3);

      computable1.add(2);
      expect(forwarder.get(), 4);

      await pause();
    });

    test('forwards computation transform', () async {
      final forwarder = Computable.forwarder(0);

      expectLater(forwarder.stream(), emitsInOrder([0, 10]));

      final computable1 = Computable(1);
      final computable2 = Computable(2);
      Computable<int>? computable3;

      final transform = Computable.transform2(
        computable1,
        computable2,
        (value1, value2) => computable3 = Computable(value1 + value2),
      );

      forwarder.forward(transform);
      expect(forwarder.get(), 3);

      computable1.add(2);
      expect(forwarder.get(), 4);

      computable3!.add(5);
      expect(forwarder.get(), 5);

      computable1.add(3);
      computable2.add(3);

      /// The forwarder should take both updates into account and return the latest value.
      expect(forwarder.get(), 6);

      computable3!.add(1);
      computable1.add(4);

      // The forwarder should favor the change to the underlying input computable over a change on the derived computable.
      expect(forwarder.get(), 7);

      computable1.add(5);
      forwarder.add(10);

      // The forwarder should favor newer values added directly to it over the older values from its dependencies.
      expect(forwarder.get(), 10);
    });

    test('forwards stream', () async {
      final forwarder = Computable.forwarder(0);
      forwarder.forwardStream(Stream.value(1));

      expect(forwarder.get(), 0);
      await pause();
      expect(forwarder.get(), 1);
    });

    test('forwards future', () async {
      final forwarder = Computable.forwarder(0);
      forwarder.forwardFuture(Future.value(1));

      expect(forwarder.get(), 0);
      await pause();
      expect(forwarder.get(), 1);
    });

    test(
      'forwards multiple computations',
      () {
        final forwarder = Computable.forwarder(0);

        expectLater(forwarder.stream(), emitsInOrder([0, 6]));

        final computable1 = Computable(1);
        final computable2 = Computable(2);

        final computation1 = computable1.map((val) {
          return forwarder.get() + val;
        });
        final computation2 = computable2.map((val) {
          return forwarder.get() + val;
        });

        forwarder.forward(computation1);
        forwarder.forward(computation2);

        expect(forwarder.get(), 3);

        computable1.add(2);
        computable2.add(3);

        expect(forwarder.get(), 6);
      },
    );

    test(
      'prioritizes a new forwarded computable',
      () {
        final forwarder = Computable.forwarder(0);
        final computable1 = Computable(1);
        final computable2 = Computable(2);

        forwarder.forward(computable1);
        computable1.add(3);
        forwarder.forward(computable2);

        // Even though computable1 has been updated after computable2 and has a newer value,
        // the forwarding of computable2 is considered the latest update to the forwarder.
        expect(forwarder.get(), 2);

        computable2.add(4);
        computable1.add(5);
        expect(forwarder.get(), 5);
      },
    );
  });

  group('Benchmark', () {
    setUpAll(() {
      print('Benchmarking...');
    });

    tearDownAll(() {
      print('Benchmarking complete.');
    });

    test('Test complex dependency graph resolution', () {
      final List<Computable> layer1 = [];
      final List<Computable> layer2 = [];
      final List<Computable> layer3 = [];

      for (int i = 0; i < 1000; i++) {
        layer1.add(Computable(i));
      }

      for (int i = 0; i < 100; i++) {
        layer2.add(
          Computation<num>(
            computables: [...layer1],
            compute: (values) => values.fold(0, (acc, value) => acc + value),
          ),
        );
      }

      for (int i = 0; i < 100; i++) {
        layer3.add(
          Computation<num>(
            computables: [...layer2],
            compute: (values) => values.fold(0, (acc, value) => acc + value),
          ),
        );
      }

      final computation = Computation<num>(
        computables: [...layer3],
        compute: (values) => values.fold(0, (acc, value) => acc + value),
      );

      print('Initial get...');
      var stopwatch = Stopwatch()..start();
      computation.get();
      stopwatch.stop();

      print('Elapsed time: ${stopwatch.elapsedMilliseconds}ms');

      expect(stopwatch.elapsedMilliseconds < 200, true);

      print('Mutation...');
      stopwatch.reset();
      stopwatch.start();
      layer1.first.add(layer1.first.get() + 1);
      computation.get();
      stopwatch.stop();

      print('Elapsed time: ${stopwatch.elapsedMilliseconds}ms');

      expect(stopwatch.elapsedMilliseconds < 100, true);

      print('Clean get...');
      stopwatch.reset();
      stopwatch.start();
      computation.get();
      stopwatch.stop();

      print('Elapsed time: ${stopwatch.elapsedMilliseconds}ms');

      expect(stopwatch.elapsedMilliseconds < 100, true);
    });
  });
}
