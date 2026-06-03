namespace DependencyInjection
{
    /// <summary>
    /// Lifecycle hook invoked once after the binding's instance is constructed
    /// and its dependencies are injected, during <see cref="Container.Bootstrap"/>.
    /// </summary>
    public interface IInitializable
    {
        void Initialize();
    }
}
