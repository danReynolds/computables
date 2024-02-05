import 'package:computables/computables.dart';
import 'package:flutter/material.dart';

class ComputableZone<T> extends StatefulWidget {
  final Widget Function(BuildContext) builder;

  const ComputableZone({
    super.key,
    required this.builder,
  });

  @override
  ComputableZoneState<T> createState() => ComputableZoneState<T>();
}

class ComputableZoneState<T> extends State<ComputableZone<T>> {
  Computation<Widget>? _computation;

  @override
  build(context) {
    _computation ??= Computation(() => widget.builder(context));

    return StreamBuilder<Widget>(
      initialData: _computation!.get(),
      stream: _computation!.stream(),
      builder: (context, childSnap) => childSnap.data!,
    );
  }
}

class ComputableFactoryBuilder<T> extends StatefulWidget {
  final Computable<T> Function() factory;
  final Widget Function(BuildContext, T) builder;

  const ComputableFactoryBuilder({
    super.key,
    required this.factory,
    required this.builder,
  });

  @override
  ComputableFactoryBuilderState<T> createState() =>
      ComputableFactoryBuilderState<T>();
}

class ComputableFactoryBuilderState<T>
    extends State<ComputableFactoryBuilder<T>> {
  late final Computable<T> _computable;

  @override
  initState() {
    super.initState();
    _computable = widget.factory();
  }

  @override
  dispose() {
    super.dispose();
    _computable.dispose();
  }

  @override
  build(context) {
    return ComputableBuilder<T>(
      computable: _computable,
      builder: widget.builder,
    );
  }
}

class ComputableBuilder<T> extends StatelessWidget {
  final Computable<T> computable;
  final Widget Function(BuildContext, T) builder;

  const ComputableBuilder({
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

  static factory<T>({
    required Computable<T> Function() factory,
    required Widget Function(BuildContext, T) builder,
    Key? key,
  }) {
    return ComputableFactoryBuilder<T>(
      key: key,
      factory: factory,
      builder: builder,
    );
  }
}
