import 'package:computables/computables.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> wait() {
  return Future.delayed(const Duration(milliseconds: 1), () {});
}

void main() {
  test('Computations', () async {
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

    expect(computation.get(), 0);

    expectLater(
      computation.stream(),
      emitsInOrder([0, 1, 3]),
    );
  });
}
