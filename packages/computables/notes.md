Right now computables eagerly recompute using synchronous stream controllers.

This is inefficient, as it causes lots of recomputes for example if an input computable to another computable changes 100x for whatever
reason in the same tick of the event loop.

Its value is delivered on stream async anyways, so it's unnecessary to be doing it synchronously **unless** the value is being asked for synchronously.

We will therefore make it so that computables can be marked as dirty and mark their dependents as dirty when they're marked as dirty (if they aren't already).

This way, then if the value is accessed synchronously, it is recomputed, otherwise it defers the recomputation until async on the event loop (if it is being observed).

So we move back to each computable having one async stream controller for external accessors, while internally it just schedules an update on the event loop when it's marked as dirty and then iterates through its dependents if any are dirty to recompute itself when that runs.

Not quite as nifty as using sync stream controllers but more efficient haha.