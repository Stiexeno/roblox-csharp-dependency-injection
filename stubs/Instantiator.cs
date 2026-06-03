namespace DependencyInjection
{
    /// <summary>
    /// Default <see cref="IInstantiator"/> implementation backed by a
    /// <see cref="Container"/>'s binding graph.
    /// </summary>
    public class Instantiator : IInstantiator
    {
        public Instantiator(Container container) { }

        public T Instantiate<T>() => default;
    }
}
