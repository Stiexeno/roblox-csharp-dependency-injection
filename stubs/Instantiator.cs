namespace DependencyInjection
{
    // Default IInstantiator implementation. Auto-constructed and bound
    // under IInstantiator inside Container.new() — users never need to
    // register it explicitly. The C# body is empty; runtime lives in
    // ReplicatedStorage.Plugins.DependencyInjection.Instantiator.
    public class Instantiator : IInstantiator
    {
        public Instantiator(Container container) { }

        public T Instantiate<T>() => default;
    }
}
