// part of computables;

// class ComputableStreamCombiner<T> extends Computable<T> {
//   final List<StreamSubscription> _subscriptions = [];
//   late List _computableValues;
//   final T Function(List values) combiner;

//   int _completedSubscriptionCount = 0;

//   ComputableStreamCombiner(
//     List<Stream> streams,
//     this.combiner, {
//     required T initialValue,
//     super.broadcast = false,
//   }) : super(initialValue) {
//     _computableValues = List.filled(streams.length, null);

//     for (int i = 0; i < streams.length; i++) {
//       _subscriptions.add(
//         streams[i].listen((value) {
//           _computableValues[i] = value;
//           add(combiner(_computableValues));
//         }, onDone: () {
//           _completedSubscriptionCount++;
//           if (_completedSubscriptionCount == _subscriptions.length) {
//             dispose();
//           }
//         }),
//       );
//     }
//   }

//   @override
//   dispose() {
//     super.dispose();
//     for (final subscription in _subscriptions) {
//       subscription.cancel();
//     }
//   }
// }
