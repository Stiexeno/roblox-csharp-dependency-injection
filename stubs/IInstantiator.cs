namespace DependencyInjection
{
    // Constructs an instance of T with DI-resolved ctor args. Unlike
    // Resolve<T>(), the target type does NOT need to be bound in the
    // container — its ctor PARAMS do, but T itself is treated as
    // transient (caller owns lifetime).
    //
    // Use for things that are conceptually owned by their parent
    // service rather than the container: state-machine states, pooled
    // worker classes, per-request command handlers. Pattern from
    // Zenject's IInstantiator.Instantiate<T>().
    //
    // Auto-bound by Container.new() so any service can inject it
    // without an explicit installer line.
    public interface IInstantiator
    {
        T Instantiate<T>();
    }
}
