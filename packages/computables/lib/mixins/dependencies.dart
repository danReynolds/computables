part of '../computables.dart';

/// A mixin that enables a [Computable] to depend on other computables.
mixin Dependencies<T> on Computable<T> {
  bool _isScheduled = false;

  /// The dependencies of this computable.
  final Set<Computable> _dependencies = {};

  void _addDependency(Computable dependency) {
    _dependencies.add(dependency);

    if (isActive) {
      dependency._addDependent(this);
    }
  }

  void _removeDependency(Computable dependency) {
    _dependencies.remove(dependency);

    if (isActive) {
      dependency._removeDependent(this);
    }
  }

  @override
  _addDependent(dependent) {
    if (!isActive) {
      for (final dependency in _dependencies) {
        dependency._addDependent(this);
      }
    }

    super._addDependent(dependent);
  }

  @override
  _removeDependent(dependent) {
    super._removeDependent(dependent);

    if (!isActive) {
      for (final dependency in _dependencies) {
        dependency._removeDependent(this);
      }
    }
  }

  @override
  _initController() {
    final controller = super._initController();

    controller.onListen = () {
      // On adding its first listener, the computable adds itself as a dependent to all of its dependencies.
      for (final dependency in _dependencies) {
        dependency._addDependent(this);
      }
    };
    controller.onCancel = () {
      // On removing its last listener, the computable removes itself as a dependent from all of its dependencies.
      if (_dependents.isEmpty) {
        for (final dependency in _dependencies) {
          dependency._removeDependent(this);
        }
      }
    };

    return controller;
  }

  int get dependenciesLength {
    return _dependencies.length;
  }

  // Schedules a rebroadcast of this computable's value.
  // Scheduling this recomputation asynchronously has a couple advantages:
  //
  // 1. It batches together synchronous updates from multiple dependencies into a single event.
  // 2. It breaks up dependency rebroadcasts across different ticks of the event loop, freeing
  //    up the isolate to do other work in between.
  void _scheduleBroadcast() {
    if (_isScheduled) {
      return;
    }

    _isScheduled = true;
    Future.delayed(Duration.zero, () {
      add(get());
      _isScheduled = false;
    });
  }

  /// A callback invoked when a dependency of the computable changes its value.
  _onDependencyChange(Computable dependency) {
    // Schedule a rebroadcast of this computable's value whenever any of its dependencies are updated.
    _scheduleBroadcast();
  }
}
