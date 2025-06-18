part of '../../computables.dart';

extension ComputableIterableNumExtensions on Iterable<int> {
  int max() {
    return reduce((a, b) => a > b ? a : b);
  }
}
