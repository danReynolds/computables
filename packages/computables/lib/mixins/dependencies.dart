part of '../computables.dart';

/// A mixin that enables a [Computable] to depend on other computables.
mixin Dependencies<T> on Computable<T> {
  bool _pendingBroadcast = false;

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
      // If this is the computable's first listener, then this computable becomes active and starts
      // subscribing to changes from its dependencies.
      if (_dependents.isEmpty) {
        for (final dependency in _dependencies) {
          dependency._addDependent(this);
        }
      }
    };
    controller.onCancel = () {
      // If this was the computable's last listener, then it is no longer active and it can stop
      // depending on changes from its dependencies.
      if (_dependents.isEmpty) {
        for (final dep in _dependencies) {
          dep._removeDependent(this);
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
    if (_pendingBroadcast) {
      return;
    }

    _pendingBroadcast = true;
    Future.delayed(Duration.zero, () {
      add(get());
      _pendingBroadcast = false;
    });
  }

  _onDependencyChange(Computable dependency) {
    // Schedule a rebroadcast of this computable's value whenever any of its dependencies change.
    _scheduleBroadcast();
  }
}
