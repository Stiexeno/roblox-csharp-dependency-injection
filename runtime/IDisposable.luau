-- Marker table for IDisposable. Same pattern as IInitializable.
-- Container Dispose() (not yet wired in v1) will use this marker to
-- find singletons that need cleanup on teardown.

return {}
