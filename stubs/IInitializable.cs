namespace DependencyInjection
{
    // Marker for services that need a one-shot startup hook. Implement
    // and the container's Bootstrap() will call Initialize() on you
    // after all bindings are registered. Matches Zenject's interface
    // of the same name.
    public interface IInitializable
    {
        void Initialize();
    }
}
