import 'package:computables/computables.dart';
import 'package:flutter/material.dart';

class ComputableStreamBuilder<T> extends StatelessWidget {
  final Computable<T> computable;
  final Widget Function(BuildContext, T) builder;

  const ComputableStreamBuilder({
    super.key,
    required this.computable,
    required this.builder,
  });

  @override
  build(context) {
    return StreamBuilder<T>(
      initialData: computable.get(),
      stream: computable.stream(),
      builder: (context, snap) => builder(context, snap.data as T),
    );
  }
}
